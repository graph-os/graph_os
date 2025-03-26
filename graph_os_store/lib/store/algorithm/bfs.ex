defmodule GraphOS.Store.Algorithm.BFS do
  @moduledoc """
  Implementation of Breadth-First Search algorithm.
  """

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store

  @doc """
  Execute a breadth-first search starting from the specified node.

  ## Parameters

  - `start_node_id` - The ID of the starting node
  - `opts` - Options for the BFS algorithm

  ## Returns

  - `{:ok, list(Node.t())}` - List of nodes found in BFS order
  - `{:error, reason}` - Error with reason
  """
  @spec execute(Node.id(), Keyword.t()) :: {:ok, list(Node.t())} | {:error, term()}
  def execute(start_node_id, opts) do
    with {:ok, start_node} <- Store.get(Node, start_node_id) do
      max_depth = Keyword.get(opts, :max_depth, 10)

      # Initialize queue with start node and its depth
      queue = :queue.from_list([{start_node, 0}])
      visited = MapSet.new([start_node_id])
      result = [start_node]

      # BFS implementation
      bfs_traverse(queue, visited, result, max_depth, opts)
    else
      {:error, _} -> {:error, :node_not_found}
    end
  end

  defp bfs_traverse(queue, visited, result, max_depth, opts) do
    case :queue.out(queue) do
      {:empty, _} ->
        # We've visited all reachable nodes
        {:ok, result}

      {{:value, {current_node, current_depth}}, queue_rest} ->
        if current_depth >= max_depth do
          # Continue BFS but don't add neighbors of this node
          bfs_traverse(queue_rest, visited, result, max_depth, opts)
        else
          # Get neighboring nodes based on edge criteria
          neighbors = get_neighbors(current_node, opts)

          # Filter out visited nodes
          {new_nodes, updated_visited, updated_queue} = process_neighbors(
            neighbors,
            visited,
            queue_rest,
            current_depth + 1
          )

          # Update result with new nodes
          updated_result = result ++ new_nodes

          # Continue BFS with the updated queue
          bfs_traverse(updated_queue, updated_visited, updated_result, max_depth, opts)
        end
    end
  end

  defp get_neighbors(node, opts) do
    direction = Keyword.get(opts, :direction, :outgoing)
    edge_type = Keyword.get(opts, :edge_type)

    # Build edge filter based on options
    edge_filter = build_edge_filter(node.id, direction, edge_type)

    # Get all edges matching the filter
    {:ok, edges} = Store.all(Edge, edge_filter)

    # Extract neighbor IDs from edges
    neighbor_ids = extract_neighbor_ids(edges, node.id, direction)

    # Fetch the actual node objects
    Enum.map(neighbor_ids, fn id ->
      case Store.get(Node, id) do
        {:ok, node} -> {id, node}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_edge_filter(node_id, direction, edge_type) do
    base_filter = case direction do
      :outgoing -> %{source: node_id}
      :incoming -> %{target: node_id}
      :both -> %{} # Special handling in extract_neighbor_ids
    end

    if edge_type do
      Map.put(base_filter, :type, edge_type)
    else
      base_filter
    end
  end

  defp extract_neighbor_ids(edges, node_id, direction) do
    Enum.flat_map(edges, fn edge ->
      case direction do
        :outgoing when edge.source == node_id -> [edge.target]
        :incoming when edge.target == node_id -> [edge.source]
        :both ->
          cond do
            edge.source == node_id -> [edge.target]
            edge.target == node_id -> [edge.source]
            true -> []
          end
        _ -> []
      end
    end)
  end

  defp process_neighbors(neighbors, visited, queue, next_depth) do
    Enum.reduce(neighbors, {[], visited, queue}, fn {id, node}, {nodes_acc, visited_acc, queue_acc} ->
      if MapSet.member?(visited_acc, id) do
        # Skip already visited nodes
        {nodes_acc, visited_acc, queue_acc}
      else
        # Add to results, mark as visited, add to queue
        {[node | nodes_acc], MapSet.put(visited_acc, id), :queue.in({node, next_depth}, queue_acc)}
      end
    end)
    |> then(fn {nodes, visited, queue} -> {Enum.reverse(nodes), visited, queue} end)
  end
end
