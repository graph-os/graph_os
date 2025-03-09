defmodule GraphOS.Graph.Store do
  @moduledoc """
  Context for `GraphOS.Graph` stores.

  ## Storage drivers

  - `GraphOS.Graph.Store.ETS` - An ETS-based store.
  """

  alias GraphOS.Graph.{Transaction, Operation, Node, Edge, Query}

  @doc """
  Initialize the store.

  ## Examples

      iex> GraphOS.Graph.Store.init(GraphOS.Graph.Store.ETS)
      :ok
  """
  @spec init(module()) :: :ok | {:error, term()}
  def init(module \\ GraphOS.Graph.Store.ETS) do
    module.init()
  end

  @doc """
  Execute a transaction.
  """
  @spec execute(Transaction.t()) :: Transaction.result()
  def execute(transaction) do
    transaction.store.execute(transaction)
  end

  @doc """
  Rollback a transaction.
  """
  @spec rollback(Transaction.t()) :: :ok | {:error, term()}
  def rollback(transaction) do
    transaction.store.rollback(transaction)
  end

  @doc """
  Handle an operation.
  """
  @spec handle(Operation.message()) :: :ok | {:error, term()}
  def handle(operation) do
    # Here we need a way to determine which store to use
    # This is a simplification - in a real implementation, you might need
    # to determine the store from context or pass it explicitly
    GraphOS.Graph.Store.ETS.handle(operation)
  end

  @doc """
  Close the store.
  """
  @spec close(module()) :: :ok | {:error, term()}
  def close(module \\ GraphOS.Graph.Store.ETS) do
    module.close()
  end

  # Query-related functions

  @doc """
  Execute a query against the store.

  ## Examples

      iex> GraphOS.Graph.Store.query(params, GraphOS.Graph.Store.ETS)
      {:ok, [%Node{}, ...]}
  """
  @spec query(Query.query_params(), module()) :: Query.query_result()
  def query(params, module \\ GraphOS.Graph.Store.ETS) do
    module.query(params)
  end

  @doc """
  Get a node by ID.

  ## Examples

      iex> GraphOS.Graph.Store.get_node("node1", GraphOS.Graph.Store.ETS)
      {:ok, %Node{id: "node1", ...}}
  """
  @spec get_node(Node.id(), module()) :: {:ok, Node.t()} | {:error, term()}
  def get_node(node_id, module \\ GraphOS.Graph.Store.ETS) do
    module.get_node(node_id)
  end

  @doc """
  Get an edge by ID.

  ## Examples

      iex> GraphOS.Graph.Store.get_edge("edge1", GraphOS.Graph.Store.ETS)
      {:ok, %Edge{id: "edge1", ...}}
  """
  @spec get_edge(Edge.id(), module()) :: {:ok, Edge.t()} | {:error, term()}
  def get_edge(edge_id, module \\ GraphOS.Graph.Store.ETS) do
    module.get_edge(edge_id)
  end

  @doc """
  Find nodes by property values.

  ## Examples

      iex> GraphOS.Graph.Store.find_nodes_by_properties(%{name: "John"}, GraphOS.Graph.Store.ETS)
      {:ok, [%Node{...}, ...]}
  """
  @spec find_nodes_by_properties(map(), module()) :: {:ok, list(Node.t())} | {:error, term()}
  def find_nodes_by_properties(properties, module \\ GraphOS.Graph.Store.ETS) do
    module.find_nodes_by_properties(properties)
  end
end
