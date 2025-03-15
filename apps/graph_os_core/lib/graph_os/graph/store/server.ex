defmodule GraphOS.Graph.Store.Server do
  @moduledoc """
  GenServer that manages connections to the underlying storage system.
  """
  
  use GenServer
  require Logger
  
  # Public API
  def start_link(name, adapter, options) do
    GenServer.start_link(__MODULE__, {name, adapter, options}, name: via_tuple(name))
  end
  
  def put_node(store_name, node) do
    GenServer.call(via_tuple(store_name), {:put_node, node})
  end
  
  def get_node(store_name, id) do
    GenServer.call(via_tuple(store_name), {:get_node, id})
  end
  
  def put_edge(store_name, edge) do
    GenServer.call(via_tuple(store_name), {:put_edge, edge})
  end
  
  def query(store_name, query, options) do
    GenServer.call(via_tuple(store_name), {:query, query, options})
  end
  
  def transaction(store_name, fun) do
    GenServer.call(via_tuple(store_name), {:transaction, fun})
  end
  
  def get_stats(store_name) do
    GenServer.call(via_tuple(store_name), :get_stats)
  end
  
  def clear(store_name) do
    GenServer.call(via_tuple(store_name), :clear)
  end
  
  # GenServer callbacks
  @impl true
  def init({name, adapter, options}) do
    Logger.info("Starting graph store #{inspect(name)} with adapter #{inspect(adapter)}")
    case adapter.init(options) do
      {:ok, state} -> 
        # Store config for dynamic store inheritance
        GraphOS.Graph.Store.Config.put(name, %{adapter: adapter, options: options})
        {:ok, %{name: name, adapter: adapter, state: state}}
      {:error, reason} -> 
        Logger.error("Failed to initialize graph store #{inspect(name)}: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:put_node, node}, _from, %{adapter: adapter, state: state} = data) do
    case adapter.put_node(state, node) do
      {:ok, node_id} -> {:reply, {:ok, node_id}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call({:get_node, id}, _from, %{adapter: adapter, state: state} = data) do
    case adapter.get_node(state, id) do
      {:ok, node} -> {:reply, {:ok, node}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call({:put_edge, edge}, _from, %{adapter: adapter, state: state} = data) do
    case adapter.put_edge(state, edge) do
      {:ok, edge_id} -> {:reply, {:ok, edge_id}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call({:query, query, options}, _from, %{adapter: adapter, state: state} = data) do
    case adapter.query(state, query, options) do
      {:ok, results} -> {:reply, {:ok, results}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call({:transaction, fun}, _from, %{adapter: adapter, state: state} = data) do
    case adapter.transaction(state, fun) do
      {:ok, result} -> {:reply, {:ok, result}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, %{adapter: adapter, state: state} = data) do
    case adapter.get_stats(state) do
      {:ok, stats} -> {:reply, {:ok, stats}, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  @impl true
  def handle_call(:clear, _from, %{adapter: adapter, state: state} = data) do
    case adapter.clear(state) do
      :ok -> {:reply, :ok, data}
      {:error, reason} -> {:reply, {:error, reason}, data}
    end
  end
  
  # Helper for registry lookup
  defp via_tuple(name) do
    {:via, Registry, {GraphOS.Graph.StoreRegistry, name}}
  end
end
