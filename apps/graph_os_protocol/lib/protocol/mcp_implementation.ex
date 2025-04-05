defmodule GraphOS.Protocol.MCPImplementation do
  @moduledoc """
  Concrete implementation of the MCP Server for GraphOS.
  Handles MCP requests and translates them into calls to graph_os_core.
  (Initially implementing a simple 'echo' tool for testing).
  """
  use MCP.Server,
    name: "GraphOS Server",
    description: "MCP server for GraphOS Protocol"

  require Logger
  alias GraphOS.Components.Registry # Added for execute_action
  # alias GraphOS.Store # Assuming query function is here, adjust if needed

  # --- Custom Handler Implementations ---

  # Override handle_initialize to add logging
  @impl true
  def handle_initialize(session_id, request_id, params) do
    Logger.info("Handling initialize", session_id: session_id, request_id: request_id)
    # Call the default implementation
    super(session_id, request_id, params)
  end

  # Override handle_list_tools to provide the echo tool
  @impl true
  def handle_list_tools(_session_id, request_id, _params) do
    Logger.info("Custom handle_list_tools implementation called", request_id: request_id)

    # Define a hard-coded echo tool
    tools = [
      %{
        "inputSchema" => %{ # Moved string key first
          "type" => "object",
          "properties" => %{
            "message" => %{
              "type" => "string",
              "description" => "The message to echo back."
            }
          },
          "required" => ["message"]
        },
        name: "echo", # Keyword keys after string key
        description: "Simple echo tool for testing."
      },
      %{
        "inputSchema" => %{ # String key first
          "type" => "object",
          "properties" => %{
            "path" => %{
              "type" => "string",
              "description" => "The query path (e.g., 'system.info', 'graph.nodes')."
            },
            "params" => %{
              "type" => "object",
              "description" => "Parameters for the query (filters, IDs, etc.).",
              "additionalProperties" => true
            }
          },
          "required" => ["path"]
        },
        name: "query_graph", # Keyword keys after
        description: "Query data from the GraphOS store."
      },
      %{
        "inputSchema" => %{ # String key first
          "type" => "object",
          "properties" => %{
            "component_name" => %{
              "type" => "string",
              "description" => "Name of the component (e.g., 'system_info')."
            },
            "action_name" => %{
              "type" => "string",
              "description" => "Name of the action (e.g., 'set_hostname')."
            },
            "params" => %{
              "type" => "object",
              "description" => "Input parameters required by the action.",
              "additionalProperties" => true
            }
          },
          "required" => ["component_name", "action_name"]
        },
        name: "execute_action", # Keyword keys after
        description: "Execute a predefined component action."
      }
    ]

    Logger.info("Returning #{length(tools)} tools from handle_list_tools", request_id: request_id)
    {:ok, %{tools: tools}}
  end

  # Override handle_tool_call to handle the echo tool
  @impl true
  def handle_tool_call(session_id, request_id, "echo", arguments) do
    message = arguments["message"]
    Logger.info("Executing echo tool with message: #{message}", request_id: request_id)
    # Simulate a successful tool call result structure
    {:ok, %{content: [%{type: "text", text: "You sent: #{message}"}]}}
  end

  # Handler for query_graph
  def handle_tool_call(session_id, request_id, "query_graph", arguments) do
    path = arguments["path"]
    params = arguments["params"] || %{} # Default to empty map if params are nil
    Logger.info("Executing query_graph tool with path: #{path}, params: #{inspect(params)}",
      request_id: request_id
    )

    # Placeholder: Replace with actual call to GraphOS query function
    # Example: result = GraphOS.Store.query(%{path: path, params: params})
    result = {:ok, %{query_path: path, received_params: params, note: "Query not implemented yet"}}

    case result do
      {:ok, data} ->
        # Convert result to MCP text content
        text_content = Jason.encode!(data, pretty: true)
        {:ok, %{content: [%{type: "text", text: text_content}]}}

      {:error, reason} ->
        Logger.error("query_graph failed: #{inspect(reason)}", request_id: request_id)
        # Return an MCP error structure
        {:error, %{code: :internal_error, message: "Query failed: #{inspect(reason)}"}}
    end
  end

  # Handler for execute_action
  def handle_tool_call(session_id, request_id, "execute_action", arguments) do
    component_name = arguments["component_name"]
    action_name_str = arguments["action_name"]
    params = arguments["params"] || %{} # Default to empty map if params are nil

    Logger.info(
      "Executing execute_action tool for component: #{component_name}, action: #{action_name_str}, params: #{inspect(params)}",
      request_id: request_id
    )

    try do
      action_name_atom = String.to_atom(action_name_str)

      # Assuming conn context is handled appropriately or not needed here
      # The session_id might be useful for context later
      conn_context = %{mcp_session_id: session_id}

      case Registry.execute_action(component_name, action_name_atom, conn_context, params) do
        {:ok, result_data} ->
          text_content = Jason.encode!(result_data, pretty: true)
          {:ok, %{content: [%{type: "text", text: text_content}]}}

        {:error, reason} ->
          Logger.error("execute_action failed: #{inspect(reason)}", request_id: request_id)
          {:error, %{code: :internal_error, message: "Action failed: #{inspect(reason)}"}}
      end
    rescue
      e in ArgumentError ->
        Logger.error("Invalid action name: #{action_name_str}", request_id: request_id)
        {:error, %{code: :invalid_params, message: "Invalid action name: #{action_name_str}"}}
    end
  end

  # Catch-all for unknown tools
  def handle_tool_call(_session_id, request_id, tool_name, _arguments) do
    Logger.warn("Received call for unknown tool: #{tool_name}", request_id: request_id)
    {:error, %{code: :method_not_found, message: "Tool '#{tool_name}' not found."}}
  end

  # All other handlers will use the default implementations from MCP.Server
end
