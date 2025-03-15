defmodule GraphOS.Graph.Store.Config do
  @moduledoc """
  Manages configuration for graph stores to enable dynamic store creation
  with inherited configurations.
  """
  
  use GenServer
  
  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @doc """
  Store configuration for a named store.
  """
  def put(store_name, config) do
    GenServer.call(__MODULE__, {:put, store_name, config})
  end
  
  @doc """
  Get configuration for a named store.
  """
  def get(store_name) do
    GenServer.call(__MODULE__, {:get, store_name})
  end
  
  @doc """
  List all stored configurations.
  """
  def list do
    GenServer.call(__MODULE__, :list)
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_) do
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:put, store_name, config}, _from, state) do
    {:reply, :ok, Map.put(state, store_name, config)}
  end
  
  @impl true
  def handle_call({:get, store_name}, _from, state) do
    case Map.fetch(state, store_name) do
      {:ok, config} -> {:reply, config, state}
      :error -> {:reply, nil, state}
    end
  end
  
  @impl true
  def handle_call(:list, _from, state) do
    {:reply, state, state}
  end
end
