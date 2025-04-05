defmodule MCP.Dispatcher do
  @moduledoc """
  Handles dispatching of MCP requests and notifications.

  This module contains the core logic for validating messages, checking session
  state, and calling the appropriate implementation module callbacks.
  """
  require Logger
  alias SSE.ConnectionRegistry
  alias MCP.Message

  # Error codes (copied from MCP.Server)
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603
  @not_initialized -32000
  @protocol_version_mismatch -32001
  @tool_not_found -32002

  # --- Public Dispatch Functions ---

  @doc """
  Handles an incoming JSON-RPC request message.

  Validates session state and delegates to the appropriate method dispatcher.
  """
  def handle_request(implementation_module, session_id, request) do
    method = request["method"]
    params = request["params"] || %{}
    request_id = request["id"]

    case MCP.Server.get_session_data(session_id) do # Still use MCP.Server helper for now
      {:ok, session_data} ->
        # For all methods except initialize, ensure the session is initialized
        if method != "initialize" && !Map.get(session_data, :initialized, false) do
          {:error, {@not_initialized, "Session not initialized", nil}}
        else
          try do
            # Delegate to the specific method dispatcher
            dispatch_method(implementation_module, session_id, method, request_id, params, session_data)
          rescue
            e ->
              stacktrace = __STACKTRACE__
              Logger.error("Error handling request", [
                session_id: session_id,
                method: method,
                error: inspect(e),
                stacktrace: inspect(stacktrace)
              ])
              {:error, {@internal_error, "Internal error", %{message: inspect(e)}}}
          end
        end

      {:error, :not_found} ->
        Logger.error("Session not found during request handling", [session_id: session_id, method: method])
        {:error, {@internal_error, "Session not found", nil}}
    end
  end

  @doc """
  Handles an incoming JSON-RPC notification message.
  """
  def handle_notification(implementation_module, session_id, notification) do
    method = notification["method"]
    params = notification["params"] || %{}

    Logger.debug("Handling notification",
      session_id: session_id,
      method: method
    )

    case MCP.Server.get_session_data(session_id) do # Still use MCP.Server helper for now
      {:ok, session_data} ->
        # Process async
        Task.start(fn ->
          try do
            # Delegate to implementation module's notification handler if defined,
            # otherwise ignore (as per previous default behavior).
            if function_exported?(implementation_module, :handle_notification, 4) do
              apply(implementation_module, :handle_notification, [session_id, method, params, session_data])
            else
              # Default: ignore notification
              :ok
            end
          rescue
            e ->
              Logger.error("Error handling notification", [
                session_id: session_id,
                method: method,
                error: inspect(e)
              ])
          end
        end)
        :ok # Always return :ok for notifications

      {:error, :not_found} ->
        Logger.warning("Session not found for notification", session_id: session_id)
        :ok # Still return :ok even if session not found
    end
  end

  @doc """
  Public entry point mirroring the original MCP.Server.dispatch_request/4.
  Used by SSE.ConnectionHandler.
  """
  def dispatch_request(implementation_module, session_id, request, session_data) do
     # This function now primarily acts as a wrapper around handle_request
     # to maintain the previous public API signature if needed elsewhere,
     # but the core logic is in handle_request/3.
     # We might simplify this further later.
     handle_request(implementation_module, session_id, request)
  end


  # --- Private Method Dispatcher ---

  defp dispatch_method(implementation_module, session_id, "initialize", request_id, params, _session_data) do
    if supported_version?(params) do
      # Original logic: Call implementation first, then update registry
      case apply(implementation_module, :handle_initialize, [session_id, request_id, params]) do
        {:ok, result} ->
          # Update registry data after successful implementation call
          update_result = ConnectionRegistry.update_data(session_id, %{
            protocol_version: Map.get(params, "protocolVersion"),
            capabilities: Map.get(result, :capabilities, %{}), # Get capabilities from result
            initialized: true,
            client_info: Map.get(params, "clientInfo", %{})
            # Existing data like PIDs will be merged by update_data
          })

          if update_result == :ok do
            # Implementation and update succeeded, format the response
            initialize_result = %MCP.Message.V20241105InitializeResult{
              protocolVersion: result.protocolVersion,
              capabilities: result.capabilities, # Use capabilities from result
              serverInfo: result.serverInfo,
              instructions: Map.get(result, :instructions) # Keep potential nil here for struct creation
            }
            # Encode the result, explicitly removing nil fields (_meta, instructions)
            encoded_result =
              MCP.Message.V20241105InitializeResult.encode(initialize_result)
              |> Enum.reject(fn {_k, v} -> is_nil(v) end) # Remove keys with nil values
              |> Enum.into(%{})

            response = %{jsonrpc: "2.0", id: request_id, result: encoded_result}
            {:ok, response}
          else
            # Failed to update registry after successful initialize
            Logger.error("Failed to update registry for session #{session_id} after initialize")
            {:error, {@internal_error, "Internal server error updating session state", nil}}
          end
        {:error, reason} -> {:error, reason} # handle_initialize failed
      end
    else
      supported = Enum.join(MCP.supported_versions(), ", ")
      error_message = if params["protocolVersion"], do: "Unsupported protocol version: #{params["protocolVersion"]}. Supported versions: #{supported}", else: "Missing protocolVersion parameter"
      {:error, {@protocol_version_mismatch, error_message, nil}}
    end
  end

  defp dispatch_method(implementation_module, session_id, "ping", request_id, _params, _session_data) do
    case apply(implementation_module, :handle_ping, [session_id, request_id]) do
      {:ok, result} ->
        ping_result = %MCP.Message.V20241105PingResult{}
        response = %{jsonrpc: "2.0", id: request_id, result: Map.merge(MCP.Message.V20241105PingResult.encode(ping_result), result)}
        {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch_method(implementation_module, session_id, "tools/register", request_id, params, session_data) do
    tool = params["tool"]
    case validate_tool(tool) do # Assuming validate_tool remains or is moved here
      {:ok, _} ->
        tool_name = tool["name"]
        current_tools = Map.get(session_data, :tools, %{})
        tools = Map.put(current_tools, tool_name, tool)
        update_result = ConnectionRegistry.update_data(session_id, %{tools: tools})
        if update_result == :ok do
          {:ok, %{jsonrpc: "2.0", id: request_id, result: %{}}}
        else
          Logger.error("Failed to update registry for session #{session_id} during tools/register")
          {:error, {@internal_error, "Internal server error updating session state", nil}}
        end
      {:error, reason} ->
        {:error, {@invalid_params, "Invalid tool definition: #{reason}", nil}}
    end
  end

  defp dispatch_method(implementation_module, session_id, "tools/list", request_id, params, session_data) do
    Logger.debug("Dispatching tools/list request", session_id: session_id, request_id: request_id)

    # Look at any tools registered with the session data
    registered_tools = Map.get(session_data, :tools, %{})
    Logger.debug("Session has #{map_size(registered_tools)} registered tools")

    # Also get tools from the implementation module if available
    # This should provide tools defined with the 'tool' macro
    case apply(implementation_module, :handle_list_tools, [session_id, request_id, params]) do
      {:ok, result} ->
        Logger.debug("Implementation module returned #{length(result.tools)} tools")
        tools_list = result.tools

        list_tools_result_struct = %MCP.Message.V20241105ListToolsResult{tools: tools_list}
        # Encode the result struct and then filter out nil values
        encoded_result =
          MCP.Message.V20241105ListToolsResult.encode(list_tools_result_struct)
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Enum.into(%{})
        response = %{jsonrpc: "2.0", id: request_id, result: encoded_result}
        {:ok, response}
      {:error, reason} ->
        Logger.error("Error getting tools list: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp dispatch_method(implementation_module, session_id, "tools/call", request_id, params, _session_data) do
    # Directly delegate to the implementation module's handle_tool_call function.
    # It is the implementation's responsibility to handle "tool not found".
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    case apply(implementation_module, :handle_tool_call, [session_id, request_id, tool_name, arguments]) do
      {:ok, result} ->
        # Assuming the result from handle_tool_call is the raw data for the 'content' field
        # Let's structure it according to CallToolResultSchema (needs a 'content' list)
        # For the echo tool, the result is %{echo: "..."}. We need to wrap it.
        # A more robust implementation might have handle_tool_call return the full content list.
        # For now, we adapt the simple echo result.
        content_list =
          case result do
            %{echo: msg} -> [%{"type" => "text", "text" => msg}]
            # Add other cases if handle_tool_call returns different structures for other tools
            _ -> [%{"type" => "text", "text" => Jason.encode!(result)}] # Default fallback: encode result as JSON text
          end

        call_tool_result_struct = %MCP.Message.V20241105CallToolResult{content: content_list}
        encoded_result =
          MCP.Message.V20241105CallToolResult.encode(call_tool_result_struct)
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Enum.into(%{})
        response = %{jsonrpc: "2.0", id: request_id, result: encoded_result}
        {:ok, response}

      # Pass through errors from the implementation (e.g., if it returns {:error, {@tool_not_found, ...}})
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch_method(implementation_module, session_id, "resources/list", request_id, params, _session_data) do
     case apply(implementation_module, :handle_list_resources, [session_id, request_id, params]) do
       {:ok, result} -> {:ok, %{jsonrpc: "2.0", id: request_id, result: result}}
       {:error, reason} -> {:error, reason}
     end
   end

   defp dispatch_method(implementation_module, session_id, "resources/read", request_id, params, _session_data) do
     case apply(implementation_module, :handle_read_resource, [session_id, request_id, params]) do
       {:ok, result} -> {:ok, %{jsonrpc: "2.0", id: request_id, result: result}}
       {:error, reason} -> {:error, reason}
     end
   end

   defp dispatch_method(implementation_module, session_id, "prompts/list", request_id, params, _session_data) do
      case apply(implementation_module, :handle_list_prompts, [session_id, request_id, params]) do
        {:ok, result} -> {:ok, %{jsonrpc: "2.0", id: request_id, result: result}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp dispatch_method(implementation_module, session_id, "prompts/get", request_id, params, _session_data) do
      case apply(implementation_module, :handle_get_prompt, [session_id, request_id, params]) do
        {:ok, result} -> {:ok, %{jsonrpc: "2.0", id: request_id, result: result}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp dispatch_method(implementation_module, session_id, "complete", request_id, params, _session_data) do
      case apply(implementation_module, :handle_complete, [session_id, request_id, params]) do
        {:ok, result} -> {:ok, %{jsonrpc: "2.0", id: request_id, result: result}}
        {:error, reason} -> {:error, reason}
      end
    end

  # Fallback for unknown methods
  defp dispatch_method(_implementation_module, _session_id, method, _request_id, _params, _session_data) do
    {:error, {@method_not_found, "Method not found: #{method}", nil}}
  end

  # --- Helpers ---

  defp supported_version?(%{"protocolVersion" => version}), do: MCP.supports_version?(version)
  defp supported_version?(_), do: false # Handle missing protocolVersion

  # Copied from MCP.Server - consider moving to a shared location if needed elsewhere
  defp validate_tool(tool) do
    cond do
      not is_map(tool) ->
        {:error, "Tool must be a map"}
      not Map.has_key?(tool, "name") ->
        {:error, "Tool must have a name"}
      not Map.has_key?(tool, "description") ->
        {:error, "Tool must have a description"}
      true ->
        {:ok, tool}
    end
  end

end
