defmodule GraphOS.Graph.Store.Dynamic do
  @moduledoc """
  Creates and manages dynamic graph stores.
  Useful for creating store instances for different repositories, branches, etc.
  """
  
  require Logger
  
  @doc """
  Get or start a dynamic store with the given name and options.
  The parent_store is used for inheritance of configuration.
  """
  def get_or_start(parent_store, name, options \\ []) do
    case Registry.lookup(GraphOS.Graph.StoreRegistry, name) do
      [{pid, _}] ->
        Logger.debug("Using existing store #{inspect(name)}")
        {:ok, pid}
      [] ->
        # Get parent store configuration
        Logger.debug("Creating new dynamic store #{inspect(name)} from parent #{inspect(parent_store)}")
        parent_config = GraphOS.Graph.Store.Config.get(parent_store)
        
        # Start new store with merged configuration
        GraphOS.Graph.Store.Supervisor.start_store(
          name,
          parent_config.adapter,
          Keyword.merge(parent_config.options, options)
        )
    end
  end
  
  @doc """
  List all dynamic stores derived from a parent store.
  """
  def list_from_parent(parent_store) do
    parent_prefix = "#{parent_store}:"
    
    Registry.select(GraphOS.Graph.StoreRegistry, [{{:_, :_, :_}, [], [:'$_']}])
    |> Enum.map(fn {name, _pid, _} -> name end)
    |> Enum.filter(fn name -> 
      name != parent_store && is_binary(name) && String.starts_with?(to_string(name), parent_prefix)
    end)
  end
end
