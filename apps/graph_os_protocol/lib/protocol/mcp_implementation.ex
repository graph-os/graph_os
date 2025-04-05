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
      }
    ]
    # Removed duplicated block

    Logger.info("Returning #{length(tools)} tools from handle_list_tools", request_id: request_id)
    {:ok, %{tools: tools}}
  end

  # Override handle_tool_call to handle the echo tool
  @impl true
  def handle_tool_call(_session_id, request_id, "echo", arguments) do
    message = arguments["message"]
    Logger.info("Executing echo tool with message: #{message}", request_id: request_id)
    {:ok, %{echo: "You sent: #{message}"}}
  end

  # All other handlers will use the default implementations from MCP.Server
end
