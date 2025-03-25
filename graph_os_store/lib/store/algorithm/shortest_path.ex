defmodule GraphOS.Store.Algorithm.ShortestPath do
  @moduledoc """
  Implementation of Dijkstra's shortest path algorithm.
  """

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store

  @doc """
  Execute Dijkstra's shortest path algorithm between two nodes.

  ## Parameters

  - `source_node_id` - The ID of the source node
  - `target_node_id` - The ID of the target node
  - `opts` - Options for the shortest path algorithm

  ## Returns

  - `{:ok, list(Node.t()), number()}` - Path of nodes and the total path weight
  - `{:error, reason}` - Error with reason
  """
  @spec execute(Node.id(), Node.id(), Keyword.t()) :: {:ok, list(Node.t()), number()} | {:error, term()}
  def execute(source_node_id, target_node_id, opts) do
    with {:ok, source_node} <- Store.get(Node, source_node_id),
         {:ok, target_node} <- Store.get(Node, target_node_id) do

      # Extract options
      weight_property = Keyword.get(opts, :weight_property, "weight")
      default_weight = Keyword.get(opts, :default_weight, 1.0)
      prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)
      direction = Keyword.get(opts, :direction, :outgoing)
      edge_type = Keyword.get(opts, :edge_type)

      # Initialize Dijkstra's algorithm
      distances = %{source_node_id => 0.0}
      previous = %{}
      unvisited = :gb_sets.singleton({0.0, source_node_id})
      visited = MapSet.new()

      # Run Dijkstra's algorithm
      case dijkstra(
        unvisited,
        visited,
        distances,
        previous,
        target_node_id,
        weight_property,
        default_weight,
        prefer_lower_weights,
        direction,
        edge_type
      ) do
        {:found, distances, previous} ->
          # Reconstruct the path
          path_ids = reconstruct_path(previous, target_node_id)

          # Convert IDs to nodes
          path_nodes = Enum.map(path_ids, fn id ->
            {:ok, node} = Store.get(Node, id)
            node
          end)

          {:ok, path_nodes, Map.get(distances, target_node_id)}

        {:not_found, _, _} ->
          {:error, :no_path_exists}
      end
    else
      {:error, _} -> {:error, :node_not_found}
    end
  end

  defp dijkstra(unvisited, visited, distances, previous, target_id, weight_prop, default_weight, prefer_lower, direction, edge_type) do
    case :gb_sets.is_empty(unvisited) do
      true ->
        # No path found
        {:not_found, distances, previous}

      false ->
        # Get the node with the smallest distance
        {{current_distance, current_id}, rest} = :gb_sets.take_smallest(unvisited)

        # Check if we've reached the target
        if current_id == target_id do
          # Path found
          {:found, distances, previous}
        else
          # Mark as visited
          new_visited = MapSet.put(visited, current_id)

          # Skip if already visited with a shorter path
          if MapSet.member?(visited, current_id) do
            dijkstra(rest, visited, distances, previous, target_id, weight_prop, default_weight, prefer_lower, direction, edge_type)
          else
            # Get all neighbors
            neighbors = get_neighbors(current_id, direction, edge_type, weight_prop, default_weight)

            # Update distances to neighbors
            {new_unvisited, new_distances, new_previous} =
              update_neighbors(
                neighbors,
                rest,
                distances,
                previous,
                current_id,
                current_distance,
                new_visited,
                prefer_lower
              )

            # Continue with the next iteration
            dijkstra(
              new_unvisited,
              new_visited,
              new_distances,
              new_previous,
              target_id,
              weight_prop,
              default_weight,
              prefer_lower,
              direction,
              edge_type
            )
          end
        end
    end
  end

  defp get_neighbors(node_id, direction, edge_type, weight_prop, default_weight) do
    # Build edge filter based on options
    filter = build_edge_filter(node_id, direction, edge_type)

    # Get all edges matching the filter
    {:ok, edges} = Store.all(Edge, filter)

    # Extract neighbor IDs and weights from edges
    Enum.flat_map(edges, fn edge ->
      target_id = case direction do
        :outgoing when edge.source == node_id -> edge.target
        :incoming when edge.target == node_id -> edge.source
        :both ->
          cond do
            edge.source == node_id -> edge.target
            edge.target == node_id -> edge.source
            true -> nil
          end
        _ -> nil
      end

      if target_id do
        # Get edge weight
        weight = Map.get(edge.properties || %{}, weight_prop, default_weight)
        [{target_id, weight}]
      else
        []
      end
    end)
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

  defp update_neighbors(neighbors, unvisited, distances, previous, current_id, current_distance, visited, prefer_lower) do
    Enum.reduce(neighbors, {unvisited, distances, previous}, fn {neighbor_id, weight}, {unvisited_acc, distances_acc, previous_acc} ->
      # Skip visited neighbors
      if MapSet.member?(visited, neighbor_id) do
        {unvisited_acc, distances_acc, previous_acc}
      else
        # Calculate potential new distance
        new_distance = current_distance + weight
        current_best = Map.get(distances_acc, neighbor_id, :infinity)

        # Compare new distance with current best
        is_better = if prefer_lower do
          new_distance < current_best
        else
          new_distance > current_best
        end

        # Update if better
        if is_better do
          new_distances = Map.put(distances_acc, neighbor_id, new_distance)
          new_previous = Map.put(previous_acc, neighbor_id, current_id)
          new_unvisited = :gb_sets.add({new_distance, neighbor_id}, unvisited_acc)
          {new_unvisited, new_distances, new_previous}
        else
          {unvisited_acc, distances_acc, previous_acc}
        end
      end
    end)
  end

  defp reconstruct_path(previous, target_id) do
    # Start with the target
    path = [target_id]

    # Trace backwards
    do_reconstruct_path(previous, path, target_id)
  end

  defp do_reconstruct_path(previous, path, current_id) do
    case Map.get(previous, current_id) do
      nil -> path # We've reached the source
      prev_id -> do_reconstruct_path(previous, [prev_id | path], prev_id)
    end
  end
end
