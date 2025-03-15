defmodule GraphOS.Graph.Store.Supervisor do
  @moduledoc """
  Supervisor for graph store processes.
  """
  
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: GraphOS.Graph.StoreRegistry},
      {DynamicSupervisor, name: GraphOS.Graph.StoreSupervisor, strategy: :one_for_one}
    ]
    
    Supervisor.init(children, strategy: :one_for_all)
  end
  
  @doc """
  Start a new store process with the given name, adapter and options.
  """
  def start_store(name, adapter, options) do
    child_spec = %{
      id: {GraphOS.Graph.Store.Server, name},
      start: {GraphOS.Graph.Store.Server, :start_link, [name, adapter, options]},
      restart: :permanent
    }
    
    DynamicSupervisor.start_child(GraphOS.Graph.StoreSupervisor, child_spec)
  end
end
