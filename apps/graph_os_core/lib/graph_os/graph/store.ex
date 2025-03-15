defmodule GraphOS.Graph.Store do
  @moduledoc """
  Behaviour that defines the graph store API.
  Implementers should provide storage-specific implementations.
  """
  
  @type store_options :: keyword()
  @type query_options :: keyword()
  
  @callback init(store_options) :: {:ok, state :: term()} | {:error, reason :: term()}
  @callback put_node(state :: term(), node :: map()) :: {:ok, node_id :: String.t()} | {:error, reason :: term()}
  @callback get_node(state :: term(), id :: String.t()) :: {:ok, node :: map()} | {:error, reason :: term()}
  @callback put_edge(state :: term(), edge :: map()) :: {:ok, edge_id :: String.t()} | {:error, reason :: term()}
  @callback query(state :: term(), query :: map(), query_options()) :: {:ok, results :: list()} | {:error, reason :: term()}
  @callback transaction(state :: term(), function()) :: {:ok, result :: term()} | {:error, reason :: term()}
  @callback get_stats(state :: term()) :: {:ok, stats :: map()} | {:error, reason :: term()}
  @callback clear(state :: term()) :: :ok | {:error, reason :: term()}
  
  # Convenience function to get all registered stores
  def list_stores do
    Registry.select(GraphOS.Graph.StoreRegistry, [{{:_, :_, :_}, [], [:'$_']}])
    |> Enum.map(fn {name, _pid, _} -> name end)
  end
end
