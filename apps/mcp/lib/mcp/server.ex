defmodule MCP.Server do
  @moduledoc """
  Behaviour and base implementation for MCP (Model Context Protocol) servers.

  This module defines the behavior specification for implementing MCP servers,
  along with a `use MCP.Server` macro that provides default implementations
  for common functionality.

  ## Example

      defmodule MyApp.MCPServer do
        use MCP.Server

        @impl true
        def handle_ping(session_id, request_id) do
          {:ok, %{message: "pong"}}
        end

        @impl true
        def handle_initialize(session_id, request_id, params) do
          # Custom initialization logic
          {:ok, %{
            protocolVersion: MCP.Types.latest_protocol_version(),
            serverInfo: %{
              name: "My MCP Server",
              version: "1.0.0"
            },
            capabilities: %{
              tools: %{
                listChanged: true
              }
            }
          }}
        end

        @impl true
        def handle_list_tools(session_id, request_id, _params) do
          # Return available tools
          {:ok, %{
            tools: [
              %{
                name: "example_tool",
                description: "An example tool",
                inputSchema: %{
                  type: "object",
                  properties: %{
                    input: %{
                      type: "string"
                    }
                  }
                },
                outputSchema: %{
                  type: "object",
                  properties: %{
                    output: %{
                      type: "string"
                    }
                  }
                }
              }
            ]
          }}
        end
      end

  """

  alias SSE.ConnectionPlug
  alias SSE.ConnectionRegistry

  # Error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  # Custom error codes
  @not_initialized -32000
  @protocol_version_mismatch -32001
  @tool_not_found -32002

  defmacro __using__(_opts) do
    quote do
      @behaviour MCP.Server
      require Logger

      # Implement the start/1 callback with default behavior
      @impl true
      def start(session_id) do
        Logger.info("Starting MCP server", session_id: session_id)
        MCP.Server.setup_ping(session_id)
        :ok
      end

      # Implement the handle_message/2 callback with default routing behavior
      @impl true
      def handle_message(session_id, message) do
        Logger.debug("Handling message",
          session_id: session_id,
          method: message["method"]
        )

        # Use MCP.Message for validation
        method = message["method"]
        version = MCP.Message.latest_version()

        if method do
          case MCP.Message.get_message_module(version, method) do
            {:ok, module} -> 
              case module.validate(message) do
                {:ok, _} -> 
                  if Map.has_key?(message, "id") do
                    # This is a request
                    handle_request(session_id, message)
                  else
                    # This is a notification
                    handle_notification(session_id, message)
                    {:ok, nil}
                  end
                {:error, errors} ->
                  Logger.warning("Invalid message format",
                    session_id: session_id,
                    errors: errors
                  )
                  {:error, {MCP.Server.invalid_params(), "Invalid JSON-RPC message parameters", errors}}
              end
            {:error, _} ->
              Logger.warning("Unknown message type",
                session_id: session_id,
                method: method
              )
              {:error, {MCP.Server.method_not_found(), "Unknown message type: #{method}", nil}}
          end
        else
          Logger.warning("Invalid message format: missing method",
            session_id: session_id
          )
          {:error, {MCP.Server.invalid_request(), "Invalid JSON-RPC message: missing method", nil}}
        end
      end

      # Default notification handler
      defp handle_notification(session_id, notification) do
        method = notification["method"]
        params = notification["params"] || %{}

        Logger.debug("Handling notification",
          session_id: session_id,
          method: method
        )

        case MCP.Server.get_session_data(session_id) do
          {:ok, session_data} ->
            Task.start(fn ->
              try do
                dispatch_notification(session_id, method, params, session_data)
              rescue
                e ->
                  Logger.error("Error handling notification",
                    session_id: session_id,
                    method: method,
                    error: inspect(e)
                  )
              end
            end)

          {:error, :not_found} ->
            Logger.warning("Session not found for notification",
              session_id: session_id
            )
        end

        :ok
      end

      # Default request handler with session validation
      defp handle_request(session_id, request) do
        method = request["method"]
        params = request["params"] || %{}
        request_id = request["id"]

        case MCP.Server.get_session_data(session_id) do
          {:ok, session_data} ->
            # For all methods except initialize, ensure the session is initialized
            if method != "initialize" && !session_data.initialized do
              {:error, {MCP.Server.not_initialized(), "Session not initialized", nil}}
            else
              try do
                dispatch_method(session_id, method, request_id, params, session_data)
              rescue
                e ->
                  stacktrace = __STACKTRACE__

                  SSE.log(:error, "Error handling request",
                    session_id: session_id,
                    method: method,
                    error: inspect(e),
                    stacktrace: inspect(stacktrace)
                  )

                  {:error,
                   {MCP.Server.internal_error(), "Internal error", %{message: inspect(e)}}}
              end
            end

          {:error, :not_found} ->
            {:error, {MCP.Server.internal_error(), "Session not found", nil}}
        end
      end

      defp supported_version?(%{"protocolVersion" => version}), do: MCP.supports_version?(version)

      # Method dispatcher
      defp dispatch_method(session_id, "initialize", request_id, params, _session_data) do
        if supported_version?(params) do
          case handle_initialize(session_id, request_id, params) do
            {:ok, result} ->
              ConnectionRegistry.update_data(session_id, %{
                protocol_version: Map.get(params, "protocolVersion"),
                capabilities: Map.get(params, "capabilities", %{}),
                initialized: true,
                client_info: Map.get(params, "clientInfo", %{})
              })

              initialize_result = %MCP.Message.V20241105InitializeResult{
                protocolVersion: result.protocolVersion,
                capabilities: result.capabilities,
                serverInfo: result.serverInfo,
                instructions: Map.get(result, :instructions)
              }

              response = %{
                jsonrpc: "2.0",
                id: request_id,
                result: MCP.Message.V20241105InitializeResult.encode(initialize_result)
              }

              {:ok, response}

            {:error, reason} ->
              {:error, reason}
          end
        else
          supported = Enum.join(MCP.supported_versions(), ", ")

          {:error,
           {
             MCP.Server.protocol_version_mismatch(),
             "Unsupported protocol version: #{params["protocolVersion"]}. Supported versions: #{supported}",
             nil
           }}
        end
      end

      defp dispatch_method(session_id, "ping", request_id, _params, _session_data) do
        case handle_ping(session_id, request_id) do
          {:ok, result} ->
            ping_result = %MCP.Message.V20241105PingResult{}
            
            response = %{
              jsonrpc: "2.0",
              id: request_id,
              result: Map.merge(MCP.Message.V20241105PingResult.encode(ping_result), result)
            }
            
            {:ok, response}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "tools/register", request_id, params, session_data) do
        # Get the tool definition
        tool = params["tool"]

        # Validate the tool definition
        case validate_tool(tool) do
          {:ok, _} ->
            # Add tool to the session
            tool_name = tool["name"]
            tools = Map.put(session_data.tools, tool_name, tool)

            ConnectionRegistry.update_data(session_id, %{
              session_data
              | tools: tools
            })

            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: %{}
             }}

          {:error, reason} ->
            {:error, {MCP.Server.invalid_params(), "Invalid tool definition: #{reason}", nil}}
        end
      end

      defp dispatch_method(session_id, "tools/list", request_id, params, _session_data) do
        case handle_list_tools(session_id, request_id, params) do
          {:ok, result} ->
            # Create ListToolsResult using the Message module
            list_tools_result = %MCP.Message.V20241105ListToolsResult{
              tools: result.tools
            }
            
            # Convert to response format
            response = %{
              jsonrpc: "2.0",
              id: request_id,
              result: MCP.Message.V20241105ListToolsResult.encode(list_tools_result)
            }
            
            {:ok, response}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "tools/call", request_id, params, session_data) do
        tool_name = params["name"]
        arguments = params["arguments"] || %{}

        case Map.get(session_data.tools, tool_name) do
          nil ->
            {:error, {MCP.Server.tool_not_found(), "Tool not found: #{tool_name}", nil}}

          _tool ->
            case handle_tool_call(session_id, request_id, tool_name, arguments) do
              {:ok, result} ->
                # Create a CallToolResult message using the Message module
                call_tool_result = %MCP.Message.V20241105CallToolResult{
                  result: result
                }

                # Convert to response format
                response = %{
                  jsonrpc: "2.0",
                  id: request_id,
                  result: MCP.Message.V20241105CallToolResult.encode(call_tool_result)
                }

                {:ok, response}

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      defp dispatch_method(session_id, "resources/list", request_id, params, _session_data) do
        case handle_list_resources(session_id, request_id, params) do
          {:ok, result} ->
            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: result
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "resources/read", request_id, params, _session_data) do
        case handle_read_resource(session_id, request_id, params) do
          {:ok, result} ->
            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: result
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "prompts/list", request_id, params, _session_data) do
        case handle_list_prompts(session_id, request_id, params) do
          {:ok, result} ->
            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: result
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "prompts/get", request_id, params, _session_data) do
        case handle_get_prompt(session_id, request_id, params) do
          {:ok, result} ->
            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: result
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(session_id, "complete", request_id, params, _session_data) do
        case handle_complete(session_id, request_id, params) do
          {:ok, result} ->
            {:ok,
             %{
               jsonrpc: "2.0",
               id: request_id,
               result: result
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp dispatch_method(_session_id, method, request_id, _params, _session_data) do
        {:error, {MCP.Server.method_not_found(), "Method not found: #{method}", nil}}
      end

      # Notification dispatcher (default implementation)
      defp dispatch_notification(_session_id, _method, _params, _session_data) do
        :ok
      end

      # Implement required callbacks with default implementations
      @impl true
      def handle_ping(_session_id, _request_id), do: {:ok, %{message: "pong"}}

      @impl true
      def handle_initialize(_session_id, _request_id, params) do
        protocol_version = params["protocolVersion"]

        {:ok,
         %{
           protocolVersion: protocol_version,
           serverInfo: %{
             name: "GraphOS MCP Server",
             version: "0.1.0"
           },
           capabilities: %{
             supportedVersions: MCP.supported_versions()
           }
         }}
      end

      @impl true
      def handle_list_tools(_session_id, _request_id, _params), do: {:ok, %{tools: []}}

      @impl true
      def handle_tool_call(_session_id, _request_id, _tool_name, _arguments),
        do: {:error, {MCP.Server.method_not_found(), "Tool call not implemented", nil}}

      @impl true
      def handle_list_resources(_session_id, _request_id, _params),
        do: {:error, {MCP.Server.method_not_found(), "Resources not implemented", nil}}

      @impl true
      def handle_read_resource(_session_id, _request_id, _params),
        do: {:error, {MCP.Server.method_not_found(), "Resource reading not implemented", nil}}

      @impl true
      def handle_list_prompts(_session_id, _request_id, _params),
        do: {:error, {MCP.Server.method_not_found(), "Prompts not implemented", nil}}

      @impl true
      def handle_get_prompt(_session_id, _request_id, _params),
        do: {:error, {MCP.Server.method_not_found(), "Prompt retrieval not implemented", nil}}

      @impl true
      def handle_complete(_session_id, _request_id, _params),
        do: {:error, {MCP.Server.method_not_found(), "Completion not implemented", nil}}

      # Make callbacks overridable
      defoverridable start: 1,
                     handle_message: 2,
                     handle_ping: 2,
                     handle_initialize: 3,
                     handle_list_tools: 3,
                     handle_tool_call: 4,
                     handle_list_resources: 3,
                     handle_read_resource: 3,
                     handle_list_prompts: 3,
                     handle_get_prompt: 3,
                     handle_complete: 3
    end
  end

  # Define the behavior callbacks
  @callback start(session_id :: String.t()) :: :ok

  @callback handle_message(session_id :: String.t(), message :: map()) ::
              {:ok, map() | nil} | {:error, {integer(), String.t(), any()}}

  @callback handle_ping(session_id :: String.t(), request_id :: MCP.JSON.Schemas.request_id()) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_initialize(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_list_tools(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_tool_call(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              tool_name :: String.t(),
              arguments :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_list_resources(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_read_resource(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_list_prompts(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_get_prompt(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  @callback handle_complete(
              session_id :: String.t(),
              request_id :: MCP.JSON.Schemas.request_id(),
              params :: map()
            ) ::
              {:ok, map()} | {:error, {integer(), String.t(), any()}}

  # Public utilities and helpers for implementations
  @doc """
  Starts the MCP server for a session.

  ## Parameters

  * `session_id` - The session ID for the server
  """
  def start(session_id) do
    SSE.log(:info, "Starting MCP server", session_id: session_id)

    # Send a ping every 15 seconds to keep the connection alive
    setup_ping(session_id)
  end

  @doc """
  Handles an incoming message for a session.

  ## Parameters

  * `session_id` - The session ID for the message
  * `message` - The JSON-RPC message to process

  ## Returns

  * `{:ok, result}` - The result of the message
  * `{:error, reason}` - An error occurred
  """
  def handle_message(session_id, message) do
    SSE.log(:debug, "Handling message",
      session_id: session_id,
      method: message["method"]
    )

    # Determine message type
    case MCP.Message.get_message_module(message["jsonrpc"], message["method"]) do
      {:ok, module} -> 
        case module.validate(message) do
          {:ok, _} -> 
            if Map.has_key?(message, "id") do
              # This is a request
              handle_request(session_id, message)
            else
              # This is a notification
              handle_notification(session_id, message)
              {:ok, nil}
            end
          {:error, errors} ->
            SSE.log(:warn, "Invalid message format",
              session_id: session_id,
              errors: errors
            )
            {:error, {@invalid_request, "Invalid JSON-RPC message", errors}}
        end
      {:error, _} ->
        SSE.log(:warn, "Unknown message type",
          session_id: session_id,
          method: message["method"]
        )
        {:error, {MCP.Server.method_not_found(), "Unknown message type: #{message["method"]}", nil}}
    end
  end

  @doc """
  Sends a notification to a client.

  ## Parameters

  * `session_id` - The session ID for the client
  * `method` - The notification method
  * `params` - The notification parameters
  """
  def send_notification(session_id, method, params \\ nil) do
    SSE.log(:debug, "Sending notification",
      session_id: session_id,
      method: method
    )

    # Create notification message
    notification = %{
      jsonrpc: "2.0",
      method: method,
      params: params
    }

    # Get the connection
    case ConnectionRegistry.lookup(session_id) do
      {:ok, %{pid: pid}} ->
        ConnectionPlug.send_message(pid, notification)
        :ok

      {:error, _} ->
        {:error, :connection_not_found}
    end
  end

  # Error code accessors
  def parse_error, do: @parse_error
  def invalid_request, do: @invalid_request
  def method_not_found, do: @method_not_found
  def invalid_params, do: @invalid_params
  def internal_error, do: @internal_error
  def not_initialized, do: @not_initialized
  def protocol_version_mismatch, do: @protocol_version_mismatch
  def tool_not_found, do: @tool_not_found

  # Helper functions for implementations
  def get_session_data(session_id) do
    case ConnectionRegistry.lookup(session_id) do
      {:ok, {_pid, data}} -> {:ok, data}
      error -> error
    end
  end

  def setup_ping(session_id) do
    # Start a background process to send pings
    {:ok, _} =
      Task.start(fn ->
        ping_loop(session_id)
      end)
  end

  defp ping_loop(session_id) do
    # Send a ping every 15 seconds
    Process.sleep(15000)

    case ConnectionRegistry.lookup(session_id) do
      {:ok, _} ->
        # Send ping notification
        send_notification(session_id, "$/ping", nil)
        ping_loop(session_id)

      {:error, :not_found} ->
        # Connection closed
        :ok

      {:error, :not_started} ->
        # Registry not started yet, retry after a short delay
        Process.sleep(1000)
        ping_loop(session_id)
    end
  end

  # Private implementations (used if someone calls the module directly)
  defp handle_request(session_id, request) do
    method = request["method"]
    params = request["params"] || %{}

    case get_session_data(session_id) do
      {:ok, session_data} ->
        # For all methods except initialize, ensure the session is initialized
        if method != "initialize" && !session_data.initialized do
          {:error, {@not_initialized, "Session not initialized", nil}}
        else
          try do
            dispatch_method(session_id, method, params, session_data)
          rescue
            e ->
              stacktrace = __STACKTRACE__

              SSE.log(:error, "Error handling request",
                session_id: session_id,
                method: method,
                error: inspect(e),
                stacktrace: inspect(stacktrace)
              )

              {:error, {@internal_error, "Internal error", %{message: inspect(e)}}}
          end
        end

      {:error, :not_found} ->
        {:error, {@internal_error, "Session not found", nil}}
    end
  end

  defp handle_notification(session_id, notification) do
    method = notification["method"]
    params = notification["params"] || %{}

    SSE.log(:debug, "Handling notification",
      session_id: session_id,
      method: method
    )

    case get_session_data(session_id) do
      {:ok, session_data} ->
        # Process the notification async
        Task.start(fn ->
          try do
            dispatch_notification(session_id, method, params, session_data)
          rescue
            e ->
              SSE.log(:error, "Error handling notification",
                session_id: session_id,
                method: method,
                error: inspect(e)
              )
          end
        end)

      {:error, :not_found} ->
        SSE.log(:warn, "Session not found for notification", session_id: session_id)
    end

    :ok
  end

  defp dispatch_method(session_id, method, params, session_data) do
    # Default implementation that matches the existing one
    case method do
      "initialize" ->
        protocol_version = params["protocolVersion"]
        capabilities = params["capabilities"] || %{}

        if protocol_version do
          if MCP.supports_version?(protocol_version) do
            # Update session data
            ConnectionRegistry.update_data(session_id, %{
              protocol_version: protocol_version,
              capabilities: capabilities,
              initialized: true,
              tools: %{}
            })

            initialize_result = %MCP.Message.V20241105InitializeResult{
              protocolVersion: protocol_version,
              capabilities: capabilities,
              serverInfo: %{
                name: "GraphOS MCP Server",
                version: "0.1.0"
              },
              instructions: nil
            }

            response = %{
              jsonrpc: "2.0",
              id: params["id"],
              result: MCP.Message.V20241105InitializeResult.encode(initialize_result)
            }

            {:ok, response}
          else
            supported = Enum.join(MCP.supported_versions(), ", ")

            {:error,
             {
               @protocol_version_mismatch,
               "Unsupported protocol version: #{protocol_version}. Supported versions: #{supported}",
               nil
             }}
          end
        else
          {:error, {@invalid_params, "Protocol version required", nil}}
        end

      "tools/register" ->
        # Get the tool definition
        tool = params["tool"]

        # Validate the tool definition
        case validate_tool(tool) do
          {:ok, _} ->
            # In a real implementation, we would register the tool here
            # For this example, we'll just return a success response

            {:ok,
             %{
               jsonrpc: "2.0",
               id: params["id"],
               result: %{}
             }}

          {:error, reason} ->
            {:error, {@invalid_params, "Invalid tool definition: #{reason}", nil}}
        end

      "tools/list" ->
        tools = Map.values(session_data.tools)

        {:ok,
         %{
           jsonrpc: "2.0",
           id: session_id,
           result: %{
             tools: tools
           }
         }}

      "tools/call" ->
        tool_name = params["name"]
        arguments = params["arguments"] || %{}

        case Map.get(session_data.tools, tool_name) do
          nil ->
            {:error, {@tool_not_found, "Tool not found: #{tool_name}", nil}}

          _tool ->
            # In a real implementation, we would dispatch to a tool registry
            # For this example, we'll just return a placeholder result
            call_tool_result = %MCP.Message.V20241105CallToolResult{
              result: %{
                result: %{
                  message: "Tool #{tool_name} called with arguments: #{inspect(arguments)}"
                }
              }
            }

            response = %{
              jsonrpc: "2.0",
              id: params["id"],
              result: MCP.Message.V20241105CallToolResult.encode(call_tool_result)
            }

            {:ok, response}
        end

      "ping" ->
        ping_result = %MCP.Message.V20241105PingResult{}
        
        response = %{
          jsonrpc: "2.0",
          id: params["id"],
          result: Map.merge(MCP.Message.V20241105PingResult.encode(ping_result), params)
        }
        
        {:ok, response}

      _ ->
        {:error, {@method_not_found, "Method not found: #{method}", nil}}
    end
  end

  defp dispatch_notification(_session_id, _method, _params, _session_data) do
    # Default implementation - does nothing
    :ok
  end

  @doc """
  Validates that a tool has the required structure.

  ## Parameters

  * `tool` - The tool to validate

  ## Returns

  * `{:ok, tool}` - If the tool is valid
  * `{:error, reason}` - If the tool is invalid
  """
  def validate_tool(tool) do
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
