defmodule GraphOS.Store.Algorithm do
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

  alias GraphOS.Store.{Node, Edge}

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
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Examples

      iex> GraphOS.Store.Algorithm.bfs("person1")
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}

      iex> GraphOS.Store.Algorithm.bfs("person1", max_depth: 2, edge_type: "knows", weighted: true)
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}
  """
  @spec bfs(Node.id(), algorithm_opts()) :: traversal_result()
  def bfs(start_node_id, opts \\ []) do
    # Add weighted flag to options
    opts =
      opts
      |> Keyword.put_new(:algorithm, :bfs)
      |> Keyword.put_new(:weighted, false)
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:prefer_lower_weights, true)

    # Create a query operation for the BFS traversal
    query = %GraphOS.Store.Query{
      operation: :traverse,
      start_node_id: start_node_id,
      opts: opts
    }

    # Execute the query operation
    GraphOS.Store.execute(query)
  end

  @doc """
  Finds the shortest path between two nodes using Dijkstra's algorithm.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of traversal, one of `:outgoing`, `:incoming`, or `:both` (default: `:outgoing`)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:default_weight` - Default weight to use when a property is not found (default: 1.0)
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Examples

      iex> GraphOS.Store.Algorithm.shortest_path("person1", "person5")
      {:ok, [%Node{id: "person1"}, %Node{id: "person3"}, %Node{id: "person5"}], 7.5}

      iex> GraphOS.Store.Algorithm.shortest_path("city1", "city3", weight_property: "distance")
      {:ok, [%Node{id: "city1"}, %Node{id: "city2"}, %Node{id: "city3"}], 350.0}
  """
  @spec shortest_path(Node.id(), Node.id(), algorithm_opts()) :: path_result()
  def shortest_path(source_node_id, target_node_id, opts \\ []) do
    # Add default options
    opts =
      opts
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:default_weight, 1.0)
      |> Keyword.put_new(:prefer_lower_weights, true)

    # Create a query operation for the shortest path algorithm
    query = %GraphOS.Store.Query{
      operation: :shortest_path,
      start_node_id: source_node_id,
      target_node_id: target_node_id,
      opts: opts
    }

    # Execute the query operation
    GraphOS.Store.execute(query)
  end

  @doc """
  Finds all connected components in the graph.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of traversal, one of `:outgoing`, `:incoming`, or `:both` (default: `:both`)

  ## Examples

      iex> GraphOS.Store.Algorithm.connected_components()
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}

      iex> GraphOS.Store.Algorithm.connected_components(edge_type: "knows")
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}
  """
  @spec connected_components(algorithm_opts()) :: components_result()
  def connected_components(opts \\ []) do
    # Create a query operation for connected components
    query = %GraphOS.Store.Query{
      operation: :connected_components,
      opts: opts
    }

    # Execute the query operation
    GraphOS.Store.execute(query)
  end

  @doc """
  Performs PageRank algorithm on the graph.

  ## Options

  - `:iterations` - Number of iterations to run (default: 20)
  - `:damping` - Damping factor for the algorithm (default: 0.85)
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")

  ## Examples

      iex> GraphOS.Store.Algorithm.pagerank()
      {:ok, %{"node1" => 0.25, "node2" => 0.15, ...}}

      iex> GraphOS.Store.Algorithm.pagerank(iterations: 30, damping: 0.9, weighted: true)
      {:ok, %{"node1" => 0.22, "node2" => 0.18, ...}}
  """
  @spec pagerank(algorithm_opts()) :: pagerank_result()
  def pagerank(opts \\ []) do
    # Add weighted flag to options
    opts =
      opts
      |> Keyword.put_new(:weighted, false)
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:iterations, 20)
      |> Keyword.put_new(:damping, 0.85)

    # Create a query operation for PageRank
    query = %GraphOS.Store.Query{
      operation: :pagerank,
      opts: opts
    }

    # Execute the query operation
    GraphOS.Store.execute(query)
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

  ## Examples

      iex> GraphOS.Store.Algorithm.minimum_spanning_tree()
      {:ok, [%Edge{...}, %Edge{...}, ...], 42.5}

      iex> GraphOS.Store.Algorithm.minimum_spanning_tree(weight_property: "distance")
      {:ok, [%Edge{...}, %Edge{...}, ...], 350.0}
  """
  @spec minimum_spanning_tree(algorithm_opts()) :: mst_result()
  def minimum_spanning_tree(opts \\ []) do
    # Add default options
    opts =
      opts
      |> Keyword.put_new(:weight_property, "weight")
      |> Keyword.put_new(:default_weight, 1.0)
      |> Keyword.put_new(:prefer_lower_weights, true)

    # Create a query operation for minimum spanning tree
    query = %GraphOS.Store.Query{
      operation: :minimum_spanning_tree,
      opts: opts
    }

    # Execute the query operation
    GraphOS.Store.execute(query)
  end
end
