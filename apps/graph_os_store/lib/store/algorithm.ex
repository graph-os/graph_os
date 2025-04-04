defmodule GraphOS.Store.Algorithm do
  @moduledoc """
  Main entry point for graph algorithms in GraphOS.Store.

  This module provides a unified API for executing various graph algorithms
  on the stored graph data.
  """

  alias GraphOS.Store.Algorithm.{
    BFS,
    ConnectedComponents,
    MinimumSpanningTree,
    PageRank,
    ShortestPath
  }

  @doc """
  Execute a breadth-first search algorithm starting from the specified node.

  ## Parameters

  - `start_node_id` - The ID of the starting node
  - `opts` - Options for the BFS algorithm
    - `:max_depth` - Maximum depth to traverse (default: 10)
    - `:direction` - Direction to traverse (:outgoing, :incoming, or :both) (default: :outgoing)
    - `:edge_type` - Optional filter for specific edge types

  ## Returns

  - `{:ok, list(Node.t())}` - List of nodes found in BFS order
  - `{:error, reason}` - Error with reason
  """
  @spec bfs(binary(), Keyword.t()) :: {:ok, list(GraphOS.Entity.Node.t())} | {:error, term()}
  def bfs(start_node_id, opts \\ []) do
    BFS.execute(start_node_id, opts)
  end

  @doc """
  Find connected components in the graph.

  ## Parameters

  - `opts` - Options for the connected components algorithm
    - `:edge_type` - Optional filter for specific edge types
    - `:direction` - Direction to consider edges (:outgoing, :incoming, or :both) (default: :both)

  ## Returns

  - `{:ok, list(list(Node.t()))}` - List of connected components (each component is a list of nodes)
  - `{:error, reason}` - Error with reason
  """
  @spec connected_components(Keyword.t()) :: {:ok, list(list(GraphOS.Entity.Node.t()))} | {:error, term()}
  def connected_components(opts \\ []) do
    ConnectedComponents.execute(opts)
  end

  @doc """
  Find the minimum spanning tree of the graph using Kruskal's algorithm.

  ## Parameters

  - `opts` - Options for the MST algorithm
    - `:weight_property` - Property name to use for edge weights (default: "weight")
    - `:default_weight` - Default weight to use if the property is not found (default: 1.0)
    - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)
    - `:edge_type` - Optional filter for specific edge types

  ## Returns

  - `{:ok, list(Edge.t()), number()}` - List of edges in the MST and total weight
  - `{:error, reason}` - Error with reason
  """
  @spec minimum_spanning_tree(Keyword.t()) :: {:ok, list(GraphOS.Entity.Edge.t()), number()} | {:error, term()}
  def minimum_spanning_tree(opts \\ []) do
    MinimumSpanningTree.execute(opts)
  end

  @doc """
  Calculate PageRank scores for all nodes in the graph.

  ## Parameters

  - `opts` - Options for the PageRank algorithm
    - `:iterations` - Number of iterations to run (default: 20)
    - `:damping` - Damping factor (default: 0.85)
    - `:weighted` - Whether to use edge weights (default: false)
    - `:weight_property` - Property name to use for edge weights if weighted (default: "weight")

  ## Returns

  - `{:ok, map()}` - Map of node IDs to PageRank scores
  - `{:error, reason}` - Error with reason
  """
  @spec page_rank(Keyword.t()) :: {:ok, map()} | {:error, term()}
  def page_rank(opts \\ []) do
    PageRank.execute(opts)
  end

  @doc """
  Find the shortest path between two nodes using Dijkstra's algorithm.

  ## Parameters

  - `source_node_id` - The ID of the source node
  - `target_node_id` - The ID of the target node
  - `opts` - Options for the shortest path algorithm
    - `:weight_property` - Property name to use for edge weights (default: "weight")
    - `:default_weight` - Default weight to use if the property is not found (default: 1.0)
    - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)
    - `:direction` - Direction to traverse (:outgoing, :incoming, or :both) (default: :outgoing)
    - `:edge_type` - Optional filter for specific edge types

  ## Returns

  - `{:ok, list(Node.t()), number()}` - Path of nodes and the total path weight
  - `{:error, reason}` - Error with reason
  """
  @spec shortest_path(binary(), binary(), Keyword.t()) ::
    {:ok, list(GraphOS.Entity.Node.t()), number()} | {:error, term()}
  def shortest_path(source_node_id, target_node_id, opts \\ []) do
    ShortestPath.execute(source_node_id, target_node_id, opts)
  end
end
