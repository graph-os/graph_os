defmodule GraphOS.Graph.Adapters.GenServer do
  @moduledoc """
  IMPORTANT: This module is deprecated and will be removed in a future version.
  Please use `GraphOS.Adapter.GenServer` instead.
  
  A Graph adapter for direct Elixir integration via GenServer.
  
  This adapter provides a direct interface to the GraphOS Graph for Elixir
  applications. It translates GenServer calls into Graph operations and vice versa.
  
  ## Configuration
  
  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:subscription_buffer_size` - Maximum size of the subscription buffer (default: 100)
  
  ## Usage
  
  ```elixir
  # Start the adapter
  {:ok, pid} = GraphOS.Adapter.GraphAdapter.start_link(
    adapter: GraphOS.Adapter.GenServer,
    name: MyGraphAdapter,
    plugs: [
      {AuthPlug, realm: "internal"},
      LoggingPlug
    ]
  )
  
  # Execute a query
  {:ok, result} = GraphOS.Adapter.GraphAdapter.execute(
    MyGraphAdapter,
    {:query, "nodes.list", %{type: "person"}}
  )
  
  # Execute an action
  {:ok, result} = GraphOS.Adapter.GraphAdapter.execute(
    MyGraphAdapter,
    {:action, "nodes.create", %{data: %{name: "John"}}}
  )
  
  # Subscribe to graph events
  GraphOS.Adapter.GenServer.subscribe(MyGraphAdapter, "nodes.changed")
  
  # Later, you can receive events in your process like this:
  # 
  # ```elixir
  # receive do
  #   {:graph_event, "nodes.changed", event_data} ->
  #     IO.puts("Node changed: " <> inspect(event_data))
  # end
  # ```
  ```
  """
  
  require Logger
  
  @doc """
  Starts the GenServer adapter as a linked process.
  
  This function is deprecated. Please use `GraphOS.Adapter.GenServer.start_link/1` instead.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    Logger.warning("GraphOS.Graph.Adapters.GenServer is deprecated, use GraphOS.Adapter.GenServer instead")
    GraphOS.Adapter.GenServer.start_link(opts)
  end
  
  @doc """
  Subscribes to graph events of a specific type.
  
  This function is deprecated. Please use `GraphOS.Adapter.GenServer.subscribe/2` instead.
  """
  @spec subscribe(module() | pid(), binary()) :: :ok | {:error, term()}
  def subscribe(adapter, event_type) when is_binary(event_type) do
    Logger.warning("GraphOS.Graph.Adapters.GenServer is deprecated, use GraphOS.Adapter.GenServer instead")
    GraphOS.Adapter.GenServer.subscribe(adapter, event_type)
  end
  
  @doc """
  Unsubscribes from graph events of a specific type.
  
  This function is deprecated. Please use `GraphOS.Adapter.GenServer.unsubscribe/2` instead.
  """
  @spec unsubscribe(module() | pid(), binary()) :: :ok | {:error, term()}
  def unsubscribe(adapter, event_type) when is_binary(event_type) do
    Logger.warning("GraphOS.Graph.Adapters.GenServer is deprecated, use GraphOS.Adapter.GenServer instead")
    GraphOS.Adapter.GenServer.unsubscribe(adapter, event_type)
  end
  
  @doc """
  Publishes an event to subscribers.
  
  This function is deprecated. Please use `GraphOS.Adapter.GenServer.publish/3` instead.
  """
  @spec publish(module() | pid(), binary(), term()) :: :ok | {:error, term()}
  def publish(adapter, event_type, event_data) do
    Logger.warning("GraphOS.Graph.Adapters.GenServer is deprecated, use GraphOS.Adapter.GenServer instead")
    GraphOS.Adapter.GenServer.publish(adapter, event_type, event_data)
  end
  
  @doc """
  Executes an operation through the adapter.
  
  This function is deprecated. Please use `GraphOS.Adapter.GenServer.execute/3` instead.
  """
  @spec execute(module() | pid(), any(), any() | nil) :: {:ok, term()} | {:error, term()}
  def execute(adapter, operation, context \\ nil) do
    Logger.warning("GraphOS.Graph.Adapters.GenServer is deprecated, use GraphOS.Adapter.GenServer instead")
    GraphOS.Adapter.GenServer.execute(adapter, operation, context)
  end
  
  # Delegate to new module implementations
  
  defdelegate init(opts), to: GraphOS.Adapter.GenServer
  defdelegate handle_operation(operation, context, state), to: GraphOS.Adapter.GenServer
  defdelegate handle_call(msg, from, state), to: GraphOS.Adapter.GenServer
  defdelegate handle_cast(msg, state), to: GraphOS.Adapter.GenServer
  defdelegate handle_info(msg, state), to: GraphOS.Adapter.GenServer
  defdelegate terminate(reason, state), to: GraphOS.Adapter.GenServer
end