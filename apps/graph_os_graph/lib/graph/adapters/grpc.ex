defmodule GraphOS.Graph.Adapters.GRPC do
  @deprecated "Use GraphOS.Adapter.GRPC instead"
  @moduledoc """
  A Graph adapter for gRPC protocol integration.
  
  This adapter builds on top of the GenServer adapter to provide gRPC
  protocol support. It defines Protocol Buffers schemas for Graph operations,
  implements streaming for real-time updates, and provides service discovery.
  
  ## Configuration
  
  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:gen_server_adapter` - The GenServer adapter to use (default: `GraphOS.Graph.Adapters.GenServer`)
  - `:port` - Port to listen on for gRPC connections (default: 50051)
  - `:server_opts` - Additional gRPC server options (default: [])
  
  ## gRPC Services
  
  This adapter exposes the following gRPC services:
  
  - `GraphService` - Core graph operations
    - `Query` - Execute graph queries
    - `Action` - Execute graph actions
    - `Subscribe` - Stream updates from the graph
  
  - `MetadataService` - Graph metadata operations
    - `GetSchema` - Get the graph schema
    - `GetStatus` - Get the graph status
    - `ListCapabilities` - List available capabilities
  
  ## Usage
  
  ```elixir
  # Start the adapter
  {:ok, pid} = GraphOS.Graph.Adapter.start_link(
    adapter: GraphOS.Graph.Adapters.GRPC,
    name: MyGRPCAdapter,
    plugs: [
      {AuthPlug, realm: "grpc"},
      LoggingPlug
    ],
    port: 50051
  )
  
  # The gRPC server will start automatically and listen on the specified port
  ```
  
  Then use a gRPC client to connect to the server:
  
  ```bash
  # Using grpcurl to query nodes
  grpcurl -d '{"path": "nodes.list", "params": {"filters": {"type": "person"}}}' \\
    -plaintext localhost:50051 graphos.graph.v1.GraphService/Query
  ```
  """
  
  # Previously: use GraphOS.Graph.Adapter
  require Logger
  
  alias GraphOS.Graph.Adapter.Context
  alias GraphOS.Graph.Adapters.GenServer, as: GenServerAdapter
  
  # State for this adapter
  defmodule State do
    @moduledoc false
    
    @type t :: %__MODULE__{
      graph_module: module(),
      gen_server_adapter: pid(),
      port: non_neg_integer(),
      server_ref: reference() | nil,
      endpoint: pid() | nil,
      subscriptions: %{binary() => list({pid(), reference()})},
      subscription_monitors: %{reference() => {pid(), binary()}}
    }
    
    defstruct [
      :graph_module,
      :gen_server_adapter,
      :port,
      :server_ref,
      :endpoint,
      subscriptions: %{},
      subscription_monitors: %{}
    ]
  end
  
  # Client API
  
  @doc """
  Starts the GRPC adapter as a linked process.
  
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
  
  # Adapter callbacks
  
  @impl true
  def init(opts) do
    graph_module = Keyword.get(opts, :graph_module, GraphOS.Graph)
    port = Keyword.get(opts, :port, 50051)
    server_opts = Keyword.get(opts, :server_opts, [])
    
    # Start the GenServer adapter as a child
    gen_server_opts = Keyword.merge(opts, [
      adapter: Keyword.get(opts, :gen_server_adapter, GenServerAdapter),
      graph_module: graph_module
    ])
    
    case GenServerAdapter.start_link(gen_server_opts) do
      {:ok, gen_server_pid} ->
        state = %State{
          graph_module: graph_module,
          gen_server_adapter: gen_server_pid,
          port: port
        }
        
        # Start the gRPC server
        case start_grpc_server(state, server_opts) do
          {:ok, server_ref, endpoint} ->
            updated_state = %{state | server_ref: server_ref, endpoint: endpoint}
            {:ok, updated_state}
            
          {:error, reason} ->
            Logger.error("Failed to start gRPC server: #{inspect(reason)}")
            # Clean up the GenServer adapter
            GenServer.stop(gen_server_pid)
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @impl true
  def handle_operation({:query, path, params}, context, state) do
    # Delegate to the GenServer adapter
    case GenServerAdapter.execute(state.gen_server_adapter, {:query, path, params}, context) do
      {:ok, result} ->
        # Query succeeded
        {:reply, result, context, state}
        
      {:error, reason} ->
        # Query failed
        {:error, reason, context, state}
    end
  end
  
  @impl true
  def handle_operation({:action, path, params}, context, state) do
    # Delegate to the GenServer adapter
    case GenServerAdapter.execute(state.gen_server_adapter, {:action, path, params}, context) do
      {:ok, result} ->
        # Action succeeded
        {:reply, result, context, state}
        
      {:error, reason} ->
        # Action failed
        {:error, reason, context, state}
    end
  end
  
  @doc """
  Subscribes to graph events of a specific type.
  
  ## Parameters
  
    * `adapter` - The adapter module or pid
    * `event_type` - The type of events to subscribe to
    * `client_pid` - The client process to send events to
    
  ## Returns
  
    * `:ok` - Successfully subscribed
    * `{:error, reason}` - Failed to subscribe
  """
  @spec subscribe(module() | pid(), binary(), pid()) :: :ok | {:error, term()}
  def subscribe(adapter, event_type, client_pid) when is_binary(event_type) and is_pid(client_pid) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter
    
    if adapter_pid && Process.alive?(adapter_pid) do
      # Send subscription request to the adapter
      GenServer.call(adapter_pid, {:grpc_subscribe, client_pid, event_type})
    else
      {:error, :adapter_not_found}
    end
  end
  
  @doc """
  Unsubscribes from graph events of a specific type.
  
  ## Parameters
  
    * `adapter` - The adapter module or pid
    * `event_type` - The type of events to unsubscribe from
    * `client_pid` - The client process to unsubscribe
    
  ## Returns
  
    * `:ok` - Successfully unsubscribed
    * `{:error, reason}` - Failed to unsubscribe
  """
  @spec unsubscribe(module() | pid(), binary(), pid()) :: :ok | {:error, term()}
  def unsubscribe(adapter, event_type, client_pid) when is_binary(event_type) and is_pid(client_pid) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter
    
    if adapter_pid && Process.alive?(adapter_pid) do
      # Send unsubscription request to the adapter
      GenServer.call(adapter_pid, {:grpc_unsubscribe, client_pid, event_type})
    else
      {:error, :adapter_not_found}
    end
  end
  
  @doc """
  Publishes an event to subscribers.
  
  ## Parameters
  
    * `adapter` - The adapter module or pid
    * `event_type` - The type of event to publish
    * `event_data` - The event data
    
  ## Returns
  
    * `:ok` - Event published successfully
    * `{:error, reason}` - Failed to publish event
  """
  @spec publish(module() | pid(), binary(), term()) :: :ok | {:error, term()}
  def publish(adapter, event_type, event_data) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter
    
    if adapter_pid && Process.alive?(adapter_pid) do
      # Send publication request to the adapter
      GenServer.cast(adapter_pid, {:grpc_publish, event_type, event_data})
    else
      {:error, :adapter_not_found}
    end
  end
  
  # Additional GenServer callbacks for gRPC
  
  @doc false
  def handle_call({:grpc_subscribe, client_pid, event_type}, _from, %State{} = state) do
    # Monitor the client process
    monitor_ref = Process.monitor(client_pid)
    
    # Add to subscriptions
    subscriptions = Map.update(
      state.subscriptions,
      event_type,
      [{client_pid, monitor_ref}],
      fn subscribers -> [{client_pid, monitor_ref} | subscribers] end
    )
    
    # Keep track of the monitor reference
    subscription_monitors = Map.put(
      state.subscription_monitors,
      monitor_ref,
      {client_pid, event_type}
    )
    
    updated_state = %{state |
      subscriptions: subscriptions,
      subscription_monitors: subscription_monitors
    }
    
    {:reply, :ok, updated_state}
  end
  
  @doc false
  def handle_call({:grpc_unsubscribe, client_pid, event_type}, _from, %State{} = state) do
    # Find and remove the subscription
    case Map.get(state.subscriptions, event_type, []) do
      [] ->
        # No subscriptions for this event type
        {:reply, :ok, state}
        
      subscribers ->
        # Remove this subscriber
        {matching, remaining} = Enum.split_with(subscribers, fn {sub_pid, _} -> sub_pid == client_pid end)
        
        # Update subscriptions
        subscriptions = if remaining == [] do
          Map.delete(state.subscriptions, event_type)
        else
          Map.put(state.subscriptions, event_type, remaining)
        end
        
        # Remove monitors
        subscription_monitors = Enum.reduce(matching, state.subscription_monitors, fn {_, ref}, acc ->
          # Demonitor the process
          Process.demonitor(ref, [:flush])
          Map.delete(acc, ref)
        end)
        
        updated_state = %{state |
          subscriptions: subscriptions,
          subscription_monitors: subscription_monitors
        }
        
        {:reply, :ok, updated_state}
    end
  end
  
  @doc false
  def handle_cast({:grpc_publish, event_type, event_data}, %State{} = state) do
    # Get subscribers for this event type
    subscribers = Map.get(state.subscriptions, event_type, [])
    
    # Send event to all subscribers
    Enum.each(subscribers, fn {pid, _} ->
      send(pid, {:graph_event, event_type, event_data})
    end)
    
    {:noreply, state}
  end
  
  @doc false
  def handle_info({:DOWN, ref, :process, pid, _reason}, %State{} = state) do
    # Process a client process going down
    case Map.get(state.subscription_monitors, ref) do
      nil ->
        # Unknown monitor reference
        {:noreply, state}
        
      {^pid, event_type} ->
        # Remove the subscription
        subscription_monitors = Map.delete(state.subscription_monitors, ref)
        
        subscriptions = Map.update(
          state.subscriptions,
          event_type,
          [],
          fn subscribers ->
            Enum.reject(subscribers, fn {sub_pid, sub_ref} ->
              sub_pid == pid and sub_ref == ref
            end)
          end
        )
        
        # Remove empty subscription lists
        subscriptions = if subscriptions[event_type] == [] do
          Map.delete(subscriptions, event_type)
        else
          subscriptions
        end
        
        updated_state = %{state |
          subscriptions: subscriptions,
          subscription_monitors: subscription_monitors
        }
        
        {:noreply, updated_state}
    end
  end
  
  @impl true
  def terminate(reason, %State{gen_server_adapter: adapter_pid, server_ref: server_ref}) do
    # Stop the gRPC server if it's running
    if server_ref do
      stop_grpc_server(server_ref)
    end
    
    # Terminate the GenServer adapter
    if Process.alive?(adapter_pid) do
      GenServer.stop(adapter_pid, reason)
    end
    
    :ok
  end
  
  # Private functions
  
  # Start the gRPC server
  @spec start_grpc_server(State.t(), keyword()) :: {:ok, reference(), pid()} | {:error, term()}
  defp start_grpc_server(%State{port: port}, _server_opts) do
    # Note: This is a placeholder implementation that will need to be completed
    # when integrating with a real gRPC library like GRPC.Server from grpc package.
    #
    # For now, we'll just log a message indicating the server would start
    # and return a mock reference and endpoint.
    
    Logger.info("Starting gRPC server on port #{port} (placeholder implementation)")
    
    # In a real implementation, this would actually start the server using something like:
    # GRPC.Server.start(MyGRPCEndpoint, port, server_opts)
    
    # Return a mock server reference and endpoint
    mock_ref = make_ref()
    mock_endpoint = self()  # Just use the current process as a placeholder
    
    {:ok, mock_ref, mock_endpoint}
  rescue
    e ->
      Logger.error("Failed to start gRPC server: #{inspect(e)}")
      {:error, e}
  end
  
  # Stop the gRPC server
  defp stop_grpc_server(_server_ref) do
    # Note: This is a placeholder implementation that will need to be completed
    # when integrating with a real gRPC library.
    
    Logger.info("Stopping gRPC server (placeholder implementation)")
    
    # In a real implementation, this would actually stop the server using something like:
    # GRPC.Server.stop(server_ref)
    
    :ok
  end
  
  # Protocol Buffer Schema (Placeholder)
  #
  # In a real implementation, this would be defined in a separate .proto file and compiled
  # to Elixir code using protobuf-elixir or a similar library. For now, we'll include
  # example schemas as comments to illustrate the intended structure.
  
  # Example GraphService.proto:
  #
  # syntax = "proto3";
  # package graphos.graph.v1;
  #
  # service GraphService {
  #   // Execute a graph query
  #   rpc Query(QueryRequest) returns (QueryResponse);
  #
  #   // Execute a graph action
  #   rpc Action(ActionRequest) returns (ActionResponse);
  #
  #   // Subscribe to graph events
  #   rpc Subscribe(SubscribeRequest) returns (stream Event);
  # }
  #
  # message QueryRequest {
  #   string path = 1;
  #   bytes params = 2;  // JSON-encoded parameters
  # }
  #
  # message QueryResponse {
  #   bytes result = 1;  // JSON-encoded result
  # }
  #
  # message ActionRequest {
  #   string path = 1;
  #   bytes params = 2;  // JSON-encoded parameters
  # }
  #
  # message ActionResponse {
  #   bytes result = 1;  // JSON-encoded result
  # }
  #
  # message SubscribeRequest {
  #   string event_type = 1;
  # }
  #
  # message Event {
  #   string type = 1;
  #   bytes data = 2;  // JSON-encoded event data
  # }
end