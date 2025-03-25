defmodule GraphOS.Store.Algorithm.PageRank do
  @moduledoc """
  Implementation of the PageRank algorithm.
  """

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Algorithm.Weights

  @doc """
  Execute the PageRank algorithm on the graph.

  ## Parameters

  - `opts` - Options for the PageRank algorithm

  ## Returns

  - `{:ok, map()}` - Map of node IDs to PageRank scores
  - `{:error, reason}` - Error with reason
  """
  @spec execute(Keyword.t()) :: {:ok, map()} | {:error, term()}
  def execute(opts) do
    with {:ok, nodes} <- Store.all(Node, %{}),
         {:ok, edges} <- Store.all(Edge, %{}) do

      # Extract options
      iterations = Keyword.get(opts, :iterations, 20)
      damping = Keyword.get(opts, :damping, 0.85)
      weighted = Keyword.get(opts, :weighted, false)
      weight_property = Keyword.get(opts, :weight_property, "weight")

      # Create adjacency list
      adjacency_list = build_adjacency_list(edges, weighted, weight_property)

      # Get node IDs
      node_ids = Enum.map(nodes, & &1.id)

      # Initialize PageRank scores
      initial_score = 1.0 / length(node_ids)
      initial_ranks = Enum.reduce(node_ids, %{}, fn id, acc -> Map.put(acc, id, initial_score) end)

      # Run PageRank iterations
      final_ranks = run_pagerank(adjacency_list, initial_ranks, iterations, damping, node_ids)

      {:ok, final_ranks}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_adjacency_list(edges, weighted, weight_property) do
    # Group edges by source
    Enum.reduce(edges, %{}, fn edge, acc ->
      # Get edge weight using the Weights utility
      weight = if weighted do
        Weights.get_edge_weight(edge, weight_property, 1.0)
      else
        1.0
      end

      # Add edge to adjacency list
      Map.update(acc, edge.source, [{edge.target, weight}], fn targets ->
        [{edge.target, weight} | targets]
      end)
    end)
  end

  defp run_pagerank(adjacency_list, ranks, 0, _damping, _nodes), do: ranks
  defp run_pagerank(adjacency_list, ranks, iterations, damping, nodes) do
    # Calculate total number of nodes
    n = length(nodes)

    # Random jump probability
    random_jump = (1 - damping) / n

    # Calculate new ranks
    new_ranks =
      Enum.reduce(nodes, %{}, fn node_id, acc ->
        # Get nodes linking to this node and their weights
        incoming_pr =
          Enum.reduce(nodes, 0.0, fn source_id, sum ->
            case Map.get(adjacency_list, source_id) do
              nil -> sum # No outgoing edges
              targets ->
                # Check if source links to node
                case Enum.find(targets, fn {target, _weight} -> target == node_id end) do
                  nil -> sum # No direct link
                  {_, weight} ->
                    # Get total outgoing weight from source
                    total_weight = Enum.reduce(targets, 0.0, fn {_, w}, s -> s + w end)
                    # Add weighted contribution
                    sum + (ranks[source_id] * weight / total_weight)
                end
            end
          end)

        # Apply damping factor
        pr = random_jump + damping * incoming_pr

        # Add to new ranks
        Map.put(acc, node_id, pr)
      end)

    # Normalize ranks using the Weights utility
    normalized_ranks = Weights.normalize_weights(new_ranks)

    # Continue iterations
    run_pagerank(adjacency_list, normalized_ranks, iterations - 1, damping, nodes)
  end
end
