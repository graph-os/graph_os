defmodule GraphOS.Protocol.MCPImplementation do
  @moduledoc """
  Concrete implementation of the MCP Server behaviour for GraphOS.
  Handles MCP requests and translates them into calls to graph_os_core.
  (Initially implementing a simple 'echo' tool for testing).
  """
  use MCP.Server # Assuming MCP.Server behaviour exists in the './mcp' SDK dependency
  require Logger

  # Removed Core aliases for echo implementation
  # alias GraphOS.Core.Context
  # alias GraphOS.Core.SystemCommand

  # --- MCP.Server Callbacks ---

  @impl true
  def handle_initialize(session_id, request_id, params) do
    Logger.info("Handling initialize", session_id: session_id, request_id: request_id)
    # Call default implementation from MCP.Server behaviour
    super(session_id, request_id, params)
  end

  @impl true
  def handle_list_tools(session_id, request_id, _params) do
    Logger.info("Handling list_tools", session_id: session_id, request_id: request_id)

    tools = [
      %{
        name: "echo",
        description: "Simple echo tool for testing.",
        inputSchema: %{
          "type" => "object",
          "properties" => %{
            "message" => %{
              "type" => "string",
              "description" => "The message to echo back."
            }
          },
          "required" => ["message"]
         }
         # Removed non-standard outputSchema key
       }
     ]

    {:ok, %{tools: tools}}
  end

  @impl true
  def handle_tool_call(session_id, request_id, tool_name, arguments) do
    Logger.info("Handling tool_call: #{tool_name}", session_id: session_id, request_id: request_id)

    case tool_name do
      "echo" ->
        message = Map.get(arguments, "message", "No message provided")
        # Simply return the message in the expected output format
        {:ok, %{echo: "You sent: #{message}"}}

      _ ->
        {:error, {MCP.Server.tool_not_found(), "Tool not found: #{tool_name}", nil}}
    end
  end

  # Required by MCP.Server behaviour (called from default dispatch_method)
  defp validate_tool(tool) do
    # Basic validation for now, just ensure it's a map with a name
    if is_map(tool) and Map.has_key?(tool, :name) do
      {:ok, tool}
    else
      {:error, "Invalid tool structure"}
    end
  end

  # --- Helper Functions ---

  # TODO: Implement proper session/actor mapping if needed later
  # defp get_actor_id_for_session(session_id) do
  #   Logger.warn("Using placeholder actor_id for session: #{session_id}")
  #   "placeholder_actor" # Replace with actual logic
  # end

  # TODO: Implement proper error formatting if needed later
  # defp format_error({:unauthorized, _}) do
  #   {MCP.Server.internal_error(), "Authorization failed", nil} # Use a more specific code if available
  # end
  # defp format_error(reason) do
  #    {MCP.Server.internal_error(), "Tool execution failed: #{inspect(reason)}", nil}
  # end

end
