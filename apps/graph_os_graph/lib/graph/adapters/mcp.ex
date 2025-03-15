defmodule GraphOS.Graph.Adapters.MCP do
  @deprecated "Use GraphOS.Adapter.MCP instead"
  @moduledoc """
  A Graph adapter for Model Context Protocol (MCP) integration.
  
  This adapter builds on top of the JSONRPC adapter to provide MCP protocol
  support. It maps MCP methods to Graph operations and handles protocol-specific
  features like version negotiation, capability discovery, etc.
  
  ## Configuration
  
  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:jsonrpc_adapter` - The JSONRPC adapter to use (default: `GraphOS.Graph.Adapters.JSONRPC`)
  - `:protocol_version` - MCP protocol version to support (default: "2024-11-05")
  - `:server_info` - Server information to expose (default: generated)
  
  ## MCP Methods
  
  This adapter implements the MCP protocol methods:
  
  - `initialize` - Initialize the MCP session
  - `ping` - Check if the server is alive
  - `tools/register` - Register a tool
  - `tools/list` - List available tools
  - `tools/call` - Call a tool
  - `resources/list` - List available resources
  - `resources/read` - Read a resource
  - `prompts/list` - List available prompts
  - `prompts/get` - Get a prompt
  - `complete` - Request completion
  
  ## Usage
  
  ```elixir
  # Start the adapter
  {:ok, pid} = GraphOS.Graph.Adapter.start_link(
    adapter: GraphOS.Graph.Adapters.MCP,
    name: MyMCPAdapter,
    plugs: [
      {AuthPlug, realm: "mcp"},
      LoggingPlug
    ],
    server_info: %{
      name: "GraphOS MCP Server",
      version: "1.0.0"
    }
  )
  
  # Process an MCP request
  request = %{
    "jsonrpc" => "2.0",
    "id" => 1,
    "method" => "initialize",
    "params" => %{
      "protocolVersion" => "2024-11-05",
      "capabilities" => %{},
      "clientInfo" => %{
        "name" => "MCP Client",
        "version" => "1.0.0"
      }
    }
  }
  
  {:ok, response} = GraphOS.Graph.Adapters.JSONRPC.process(MyMCPAdapter, request)
  ```
  """
  
  # Previously: use GraphOS.Graph.Adapter
  require Logger
  
  alias GraphOS.Graph.Adapter.Context
  alias GraphOS.Graph.Adapters.JSONRPC, as: JSONRPCAdapter
  alias GraphOS.Graph.Adapters.GenServer, as: GenServerAdapter
  
  # State for this adapter
  defmodule State do
    @moduledoc false
    
    @type t :: %__MODULE__{
      graph_module: module(),
      jsonrpc_adapter: pid(),
      protocol_version: String.t(),
      server_info: map(),
      sessions: %{binary() => map()}
    }
    
    defstruct [
      :graph_module,
      :jsonrpc_adapter,
      :protocol_version,
      :server_info,
      sessions: %{}
    ]
  end
  
  # Client API
  
  @doc """
  Starts the MCP adapter as a linked process.
  
  ## Parameters
  
    * `opts` - Adapter configuration options
    
  ## Returns
  
    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    GraphOS.Graph.Adapter.start_link(Keyword.put(opts, :adapter, __MODULE__))
  end
  
  @doc """
  Processes an MCP request (delegate to JSONRPC adapter).
  
  ## Parameters
  
    * `adapter` - The adapter module or pid
    * `request` - The MCP request (JSON-RPC format)
    * `context` - Optional custom context for the operation
    
  ## Returns
  
    * `{:ok, response}` - Successfully processed the request
    * `{:error, reason}` - Failed to process the request
  """
  @spec process(module() | pid(), map() | list(map()), Context.t() | nil) ::
          {:ok, map() | list(map())} | {:error, term()}
  def process(adapter, request, context \\ nil) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter
    
    if adapter_pid && Process.alive?(adapter_pid) do
      # Create a new context if not provided
      context = context || Context.new()
      
      # Extract session ID from context or generate a new one
      session_id = context.metadata[:session_id] || generate_session_id()
      context = Context.put_metadata(context, :session_id, session_id)
      
      # Pass the request to the adapter as a GenServer call
      GenServer.call(adapter_pid, {:mcp_request, request, context})
    else
      {:error, :adapter_not_found}
    end
  end
  
  # Adapter callbacks
  
  @impl true
  def init(opts) do
    graph_module = Keyword.get(opts, :graph_module, GraphOS.Graph)
    protocol_version = Keyword.get(opts, :protocol_version, "2024-11-05")
    
    # Default server info
    default_server_info = %{
      "name" => "GraphOS MCP Server",
      "version" => "1.0.0"
    }
    
    server_info = Keyword.get(opts, :server_info, default_server_info)
    
    # Start the JSONRPC adapter as a child
    jsonrpc_opts = Keyword.merge(opts, [
      adapter: Keyword.get(opts, :jsonrpc_adapter, JSONRPCAdapter),
      graph_module: graph_module,
      method_prefix: ""  # No prefix for MCP methods
    ])
    
    case JSONRPCAdapter.start_link(jsonrpc_opts) do
      {:ok, jsonrpc_pid} ->
        state = %State{
          graph_module: graph_module,
          jsonrpc_adapter: jsonrpc_pid,
          protocol_version: protocol_version,
          server_info: server_info
        }
        {:ok, state}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @impl true
  def handle_operation({:query, path, params}, context, state) do
    # Delegate to the JSONRPC adapter
    case JSONRPCAdapter.process(state.jsonrpc_adapter, %{
      "jsonrpc" => "2.0",
      "id" => context.request_id,
      "method" => "graph.query.#{path}",
      "params" => params
    }, context) do
      {:ok, response} ->
        # Extract the result from the JSON-RPC response
        result = Map.get(response, "result")
        {:reply, result, context, state}
        
      {:error, reason} ->
        # Query failed
        {:error, reason, context, state}
    end
  end
  
  @impl true
  def handle_operation({:action, path, params}, context, state) do
    # Delegate to the JSONRPC adapter
    case JSONRPCAdapter.process(state.jsonrpc_adapter, %{
      "jsonrpc" => "2.0",
      "id" => context.request_id,
      "method" => "graph.action.#{path}",
      "params" => params
    }, context) do
      {:ok, response} ->
        # Extract the result from the JSON-RPC response
        result = Map.get(response, "result")
        {:reply, result, context, state}
        
      {:error, reason} ->
        # Action failed
        {:error, reason, context, state}
    end
  end
  
  # Additional GenServer callbacks for MCP requests
  
  @doc false
  def handle_call({:mcp_request, request, context}, _from, %State{} = state) do
    # Process the MCP request
    {result, _updated_context, updated_state} = process_mcp_request(request, context, state)
    {:reply, result, updated_state}
  end
  
  # Private MCP processing functions
  
  # Process an MCP request
  defp process_mcp_request(request, context, state) do
    # Extract the method to determine if it needs special MCP handling
    method = Map.get(request, "method")
    
    case method do
      "initialize" ->
        # Handle initialize specially for MCP protocol
        handle_initialize(request, context, state)
        
      "ping" ->
        # Handle ping specially for MCP protocol
        handle_ping(request, context, state)
        
      "tools/list" ->
        # Handle tools/list specially for MCP protocol
        handle_list_tools(request, context, state)
        
      "tools/call" ->
        # Handle tools/call specially for MCP protocol
        handle_tool_call(request, context, state)
        
      _ ->
        # For other methods, delegate to the JSONRPC adapter
        case JSONRPCAdapter.process(state.jsonrpc_adapter, request, context) do
          {:ok, response} ->
            {{:ok, response}, context, state}
            
          {:error, reason} ->
            {{:error, reason}, context, state}
        end
    end
  end
  
  # Handle the MCP initialize method
  defp handle_initialize(request, context, state) do
    params = Map.get(request, "params", %{})
    request_id = Map.get(request, "id")
    session_id = context.metadata[:session_id]
    
    # Check if the client's protocol version is supported
    client_version = Map.get(params, "protocolVersion")
    
    if client_version == state.protocol_version do
      # Save session information
      client_info = Map.get(params, "clientInfo", %{})
      client_capabilities = Map.get(params, "capabilities", %{})
      
      session_data = %{
        protocol_version: client_version,
        client_info: client_info,
        capabilities: client_capabilities,
        initialized: true,
        tools: %{}
      }
      
      # Store the session data
      updated_state = %{state | sessions: Map.put(state.sessions, session_id, session_data)}
      
      # Create the initialize result
      result = %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "result" => %{
          "protocolVersion" => state.protocol_version,
          "serverInfo" => state.server_info,
          "capabilities" => %{
            "supportedVersions" => [state.protocol_version]
          }
        }
      }
      
      {{:ok, result}, context, updated_state}
    else
      # Protocol version mismatch
      error = %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "error" => %{
          "code" => -32001,  # Protocol version mismatch
          "message" => "Unsupported protocol version: #{client_version}. Supported versions: #{state.protocol_version}"
        }
      }
      
      {{:ok, error}, context, state}
    end
  end
  
  # Handle the MCP ping method
  defp handle_ping(request, context, state) do
    request_id = Map.get(request, "id")
    
    # Create the ping result
    result = %{
      "jsonrpc" => "2.0",
      "id" => request_id,
      "result" => %{
        "message" => "pong"
      }
    }
    
    {{:ok, result}, context, state}
  end
  
  # Handle the MCP tools/list method
  defp handle_list_tools(request, context, state) do
    request_id = Map.get(request, "id")
    session_id = context.metadata[:session_id]
    
    # Get the session data
    session_data = Map.get(state.sessions, session_id, %{})
    
    if Map.get(session_data, :initialized, false) do
      # Query the graph for available tools
      case state.graph_module.query(type: "tool") do
        {:ok, tools} ->
          # Convert graph nodes to MCP tool definitions
          mcp_tools = Enum.map(tools, &convert_node_to_tool/1)
          
          # Create the tools/list result
          result = %{
            "jsonrpc" => "2.0",
            "id" => request_id,
            "result" => %{
              "tools" => mcp_tools
            }
          }
          
          {{:ok, result}, context, state}
          
        {:error, reason} ->
          # Failed to get tools
          error = %{
            "jsonrpc" => "2.0",
            "id" => request_id,
            "error" => %{
              "code" => -32603,  # Internal error
              "message" => "Failed to list tools: #{inspect(reason)}"
            }
          }
          
          {{:ok, error}, context, state}
      end
    else
      # Session not initialized
      error = %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "error" => %{
          "code" => -32000,  # Not initialized
          "message" => "Session not initialized"
        }
      }
      
      {{:ok, error}, context, state}
    end
  end
  
  # Handle the MCP tools/call method
  defp handle_tool_call(request, context, state) do
    params = Map.get(request, "params", %{})
    request_id = Map.get(request, "id")
    session_id = context.metadata[:session_id]
    
    # Get the session data
    session_data = Map.get(state.sessions, session_id, %{})
    
    if Map.get(session_data, :initialized, false) do
      tool_name = Map.get(params, "name")
      arguments = Map.get(params, "arguments", %{})
      
      # Query the graph for the tool
      case state.graph_module.query(type: "tool", name: tool_name) do
        {:ok, [tool | _]} ->
          # Execute the tool node
          case state.graph_module.execute_node(tool, arguments) do
            {:ok, result} ->
              # Create the tools/call result
              response = %{
                "jsonrpc" => "2.0",
                "id" => request_id,
                "result" => %{
                  "result" => result
                }
              }
              
              {{:ok, response}, context, state}
              
            {:error, reason} ->
              # Failed to execute tool
              error = %{
                "jsonrpc" => "2.0",
                "id" => request_id,
                "error" => %{
                  "code" => -32603,  # Internal error
                  "message" => "Failed to execute tool: #{inspect(reason)}"
                }
              }
              
              {{:ok, error}, context, state}
          end
          
        {:ok, []} ->
          # Tool not found
          error = %{
            "jsonrpc" => "2.0",
            "id" => request_id,
            "error" => %{
              "code" => -32002,  # Tool not found
              "message" => "Tool not found: #{tool_name}"
            }
          }
          
          {{:ok, error}, context, state}
          
        {:error, reason} ->
          # Failed to query tools
          error = %{
            "jsonrpc" => "2.0",
            "id" => request_id,
            "error" => %{
              "code" => -32603,  # Internal error
              "message" => "Failed to find tool: #{inspect(reason)}"
            }
          }
          
          {{:ok, error}, context, state}
      end
    else
      # Session not initialized
      error = %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "error" => %{
          "code" => -32000,  # Not initialized
          "message" => "Session not initialized"
        }
      }
      
      {{:ok, error}, context, state}
    end
  end
  
  # Helper functions
  
  # Convert a graph node to an MCP tool definition
  defp convert_node_to_tool(node) do
    %{
      "name" => Map.get(node.data, "name", node.id),
      "description" => Map.get(node.data, "description", ""),
      "inputSchema" => Map.get(node.data, "inputSchema", %{
        "type" => "object",
        "properties" => %{}
      }),
      "outputSchema" => Map.get(node.data, "outputSchema", %{
        "type" => "object",
        "properties" => %{}
      })
    }
  end
  
  # Generate a session ID
  defp generate_session_id do
    uuid = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4), e::binary-size(12)>> = uuid
    "#{a}-#{b}-#{c}-#{d}-#{e}"
  end
  
  @impl true
  def terminate(reason, %State{jsonrpc_adapter: adapter_pid}) do
    # Terminate the JSONRPC adapter
    if Process.alive?(adapter_pid) do
      GenServer.stop(adapter_pid, reason)
    end
    
    :ok
  end
end