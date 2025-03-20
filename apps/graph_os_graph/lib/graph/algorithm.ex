defmodule GraphOS.GraphContext.Algorithm do
  @moduledoc """
  Context for graph algorithms.

  This module provides a unified interface for various graph algorithms,
  with implementations for different storage backends.

  ## Available Algorithms

  - Breadth-First Search (BFS)
  - Shortest Path (Dijkstra's Algorithm)
  - Connected Components
  - PageRank
  - Minimum Spanning Tree (MST)
  """

  alias GraphOS.GraphContext.{Node, Edge}

  @type algorithm_opts :: keyword()
  @type traversal_result :: {:ok, list()} | {:error, term()}
  @type path_result :: {:ok, list(Node.t()), number()} | {:error, term()}
  @type components_result :: {:ok, list(list(Node.t()))} | {:error, term()}
  @type pagerank_result :: {:ok, map()} | {:error, term()}
  @type mst_result :: {:ok, list(Edge.t()), number()} | {:error, term()}

  @doc """
  Performs a breadth-first search (BFS) starting from the specified node.

  ## Options

  - `:max_depth` - Maximum traversal depth (default: 10)
  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of traversal, one of `:outgoing`, `:incoming`, or `:both` (default: `:outgoing`)
  - `:store` - The store module to use (default: GraphOS.GraphContext.Store.ETS)
  - `:optimized` - Whether to use store-specific optimizations (default: true)
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.bfs("person1")
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}

      iex> GraphOS.GraphContext.Algorithm.bfs("person1", max_depth: 2, edge_type: "knows", weighted: true)
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}
  """
  @spec bfs(Node.id(), algorithm_opts()) :: traversal_result()
  def bfs(start_node_id, opts \\ []) do
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)
    optimized = Keyword.get(opts, :optimized, true)

    # Add weighted flag to options
    opts =
      opts
      |> Keyword.put_new(:algorithm, :bfs)
      |> Keyword.put_new(:weighted, false)
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:prefer_lower_weights, true)

    # Use optimized version for ETS if requested
    if optimized && store_module == GraphOS.GraphContext.Store.ETS do
      GraphOS.GraphContext.Algorithm.ETS.optimized_bfs(start_node_id, opts)
    else
      store_module.algorithm_traverse(start_node_id, opts)
    end
  end

  @doc """
  Finds the shortest path between two nodes using Dijkstra's algorithm.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of traversal, one of `:outgoing`, `:incoming`, or `:both` (default: `:outgoing`)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:default_weight` - Default weight to use when a property is not found (default: 1.0)
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)
  - `:store` - The store module to use (default: GraphOS.GraphContext.Store.ETS)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.shortest_path("person1", "person5")
      {:ok, [%Node{id: "person1"}, %Node{id: "person3"}, %Node{id: "person5"}], 7.5}

      iex> GraphOS.GraphContext.Algorithm.shortest_path("city1", "city3", weight_property: "distance")
      {:ok, [%Node{id: "city1"}, %Node{id: "city2"}, %Node{id: "city3"}], 350.0}
  """
  @spec shortest_path(Node.id(), Node.id(), algorithm_opts()) :: path_result()
  def shortest_path(source_node_id, target_node_id, opts \\ []) do
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)

    # Add default options
    opts =
      opts
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:default_weight, 1.0)
      |> Keyword.put_new(:prefer_lower_weights, true)

    store_module.algorithm_shortest_path(source_node_id, target_node_id, opts)
  end

  @doc """
  Finds all connected components in the graph.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of traversal, one of `:outgoing`, `:incoming`, or `:both` (default: `:both`)
  - `:store` - The store module to use (default: GraphOS.GraphContext.Store.ETS)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.connected_components()
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}

      iex> GraphOS.GraphContext.Algorithm.connected_components(edge_type: "knows")
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}
  """
  @spec connected_components(algorithm_opts()) :: components_result()
  def connected_components(opts \\ []) do
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)
    store_module.algorithm_connected_components(opts)
  end

  @doc """
  Performs PageRank algorithm on the graph.

  ## Options

  - `:iterations` - Number of iterations to run (default: 20)
  - `:damping` - Damping factor for the algorithm (default: 0.85)
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:store` - The store module to use (default: GraphOS.GraphContext.Store.ETS)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.pagerank()
      {:ok, %{"node1" => 0.25, "node2" => 0.15, ...}}

      iex> GraphOS.GraphContext.Algorithm.pagerank(iterations: 30, damping: 0.9, weighted: true)
      {:ok, %{"node1" => 0.22, "node2" => 0.18, ...}}
  """
  @spec pagerank(algorithm_opts()) :: pagerank_result()
  def pagerank(opts \\ []) do
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)

    # Add weighted flag to options
    opts =
      opts
      |> Keyword.put_new(:weighted, false)
      |> Keyword.put_new(:weight_property, "weight")

    case store_module do
      GraphOS.GraphContext.Store.ETS ->
        # Use specialized implementation for ETS
        GraphOS.GraphContext.Algorithm.ETS.pagerank(opts)
      _ ->
        # Generic implementation not available yet
        {:error, :not_implemented}
    end
  end

  @doc """
  Finds the minimum spanning tree (MST) of the graph using Kruskal's algorithm.

  The minimum spanning tree is a subset of the edges that connects all the nodes
  together without any cycles and with the minimum possible total edge weight.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:default_weight` - Default weight to use when a property is not found (default: 1.0)
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)
  - `:store` - The store module to use (default: GraphOS.GraphContext.Store.ETS)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.minimum_spanning_tree()
      {:ok, [%Edge{...}, %Edge{...}, ...], 42.5}

      iex> GraphOS.GraphContext.Algorithm.minimum_spanning_tree(weight_property: "distance")
      {:ok, [%Edge{...}, %Edge{...}, ...], 350.0}
  """
  @spec minimum_spanning_tree(algorithm_opts()) :: mst_result()
  def minimum_spanning_tree(opts \\ []) do
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)

    # Add default options
    opts =
      opts
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:default_weight, 1.0)
      |> Keyword.put_new(:prefer_lower_weights, true)

    store_module.algorithm_minimum_spanning_tree(opts)
  end
end
