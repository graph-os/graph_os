defmodule GraphOS.Store.Algorithm.MinimumSpanningTree do
  @moduledoc """
  Implementation of Kruskal's Minimum Spanning Tree algorithm.
  """

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Algorithm.Utils.DisjointSet

  @doc """
  Execute Kruskal's algorithm to find the minimum spanning tree.

  ## Parameters

  - `opts` - Options for the MST algorithm

  ## Returns

  - `{:ok, list(Edge.t()), number()}` - List of edges in the MST and total weight
  - `{:error, reason}` - Error with reason
  """
  @spec execute(Keyword.t()) :: {:ok, list(Edge.t()), number()} | {:error, term()}
  def execute(opts) do
    with {:ok, nodes} <- Store.all(Node, %{}),
         {:ok, edges} <- Store.all(Edge, filter_edges(opts)) do

      # Extract options
      weight_property = Keyword.get(opts, :weight_property, "weight")
      default_weight = Keyword.get(opts, :default_weight, 1.0)
      prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)

      # Get node IDs
      node_ids = Enum.map(nodes, & &1.id)

      # Initialize disjoint set for Kruskal's algorithm
      node_set = DisjointSet.new(node_ids)

      # Sort edges by weight
      sorted_edges = sort_edges_by_weight(edges, weight_property, default_weight, prefer_lower_weights)

      # Run Kruskal's algorithm
      {mst_edges, total_weight} = kruskal(sorted_edges, node_set, [], 0.0)

      {:ok, mst_edges, total_weight}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp filter_edges(opts) do
    edge_type = Keyword.get(opts, :edge_type)
    if edge_type, do: %{type: edge_type}, else: %{}
  end

  defp sort_edges_by_weight(edges, weight_property, default_weight, prefer_lower_weights) do
    # Extract edge weights
    edges_with_weights = Enum.map(edges, fn edge ->
      weight = Map.get(edge.properties || %{}, weight_property, default_weight)
      {edge, weight}
    end)

    # Sort by weight
    Enum.sort_by(edges_with_weights, fn {_, weight} -> weight end, fn a, b ->
      if prefer_lower_weights do
        a <= b
      else
        a >= b
      end
    end)
  end

  defp kruskal([], _node_set, mst_edges, total_weight), do: {Enum.reverse(mst_edges), total_weight}
  defp kruskal([{edge, weight} | rest], node_set, mst_edges, total_weight) do
    # Find sets of source and target
    {source_root, node_set1} = DisjointSet.find(node_set, edge.source)
    {target_root, node_set2} = DisjointSet.find(node_set1, edge.target)

    # If source and target are in different sets, add edge to MST
    if source_root != target_root do
      # Union the sets
      new_node_set = DisjointSet.union(node_set2, edge.source, edge.target)

      # Add edge to MST
      kruskal(rest, new_node_set, [edge | mst_edges], total_weight + weight)
    else
      # Skip this edge (would create a cycle)
      kruskal(rest, node_set2, mst_edges, total_weight)
    end
  end
end
