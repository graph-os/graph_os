defmodule GraphOS.Graph do
  @moduledoc """
  The main module for GraphOS graph operations.

  This module provides high-level functions for interacting with the graph,
  including querying and manipulating graph data.
  """

  alias GraphOS.Graph.{Node, Edge, Transaction, Operation, Query, Store, Algorithm}

  @doc """
  Initialize the graph store.

  ## Examples

      iex> GraphOS.Graph.init()
      :ok
  """
  @spec init(module()) :: :ok
  def init(store_module \\ GraphOS.Graph.Store.ETS) do
    Store.init(store_module)
  end

  @doc """
  Query the graph using the query engine.

  ## Examples

      iex> GraphOS.Graph.query(start_node_id: "person1", edge_type: "knows")
      {:ok, [%Node{id: "person2", ...}, ...]}
  """
  @spec query(Query.query_params()) :: Query.query_result()
  def query(query_params) do
    Query.execute(query_params)
  end

  @doc """
  Executes a transaction against the graph.

  ## Examples

      iex> transaction = %Transaction{...}
      iex> GraphOS.Graph.execute(transaction)
      {:ok, result}
  """
  @spec execute(Transaction.t()) :: {:ok, term()} | {:error, term()}
  def execute(transaction) do
    Store.execute(transaction)
  end

  # Algorithm-related functions

  @doc """
  Performs a breadth-first search (BFS) starting from the specified node.

  ## Examples

      iex> GraphOS.Graph.bfs("person1")
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}
  """
  @spec bfs(Node.id(), Algorithm.algorithm_opts()) :: Algorithm.traversal_result()
  def bfs(start_node_id, opts \\ []) do
    Algorithm.bfs(start_node_id, opts)
  end

  @doc """
  Finds the shortest path between two nodes.

  ## Examples

      iex> GraphOS.Graph.shortest_path("person1", "person5")
      {:ok, [%Node{id: "person1"}, %Node{id: "person3"}, %Node{id: "person5"}], 7.5}
  """
  @spec shortest_path(Node.id(), Node.id(), Algorithm.algorithm_opts()) :: Algorithm.path_result()
  def shortest_path(source_node_id, target_node_id, opts \\ []) do
    Algorithm.shortest_path(source_node_id, target_node_id, opts)
  end

  @doc """
  Finds all connected components in the graph.

  ## Examples

      iex> GraphOS.Graph.connected_components()
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}
  """
  @spec connected_components(Algorithm.algorithm_opts()) :: Algorithm.components_result()
  def connected_components(opts \\ []) do
    Algorithm.connected_components(opts)
  end

  @doc """
  Calculates PageRank values for all nodes in the graph.

  ## Examples

      iex> GraphOS.Graph.pagerank()
      {:ok, %{"node1" => 0.25, "node2" => 0.15, ...}}
  """
  @spec pagerank(Algorithm.algorithm_opts()) :: Algorithm.pagerank_result()
  def pagerank(opts \\ []) do
    Algorithm.pagerank(opts)
  end

  @doc """
  Finds the minimum spanning tree of the graph.

  ## Examples

      iex> GraphOS.Graph.minimum_spanning_tree()
      {:ok, [%Edge{...}, ...], 42.5}
  """
  @spec minimum_spanning_tree(Algorithm.algorithm_opts()) :: Algorithm.mst_result()
  def minimum_spanning_tree(opts \\ []) do
    Algorithm.minimum_spanning_tree(opts)
  end
end
