defmodule GraphOS.GraphContext.Algorithm.ETS do
  @moduledoc """
  Optimized graph algorithm implementations for the ETS storage backend.

  This module contains specialized implementations of graph algorithms
  that take advantage of ETS-specific optimizations for better performance.
  """

  alias GraphOS.GraphContext.Algorithm.Weights

  @doc """
  Performs a specialized BFS traversal using ETS-specific optimizations.

  This version is more efficient than the generic implementation for large graphs.
  It also supports weighted traversal where edges with preferred weights are traversed first.

  ## Options

  - `max_depth` - Maximum traversal depth (default: 10)
  - `edge_type` - Filter edges by type
  - `direction` - Direction of traversal (default: :outgoing)
  - `weighted` - Whether to consider edge weights (default: false)
  - `weight_property` - The property name to use for edge weights (default: "weight")
  - `prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.ETS.optimized_bfs("person1", max_depth: 3)
      {:ok, [%Node{id: "person1"}, ...]}

      iex> GraphOS.GraphContext.Algorithm.ETS.optimized_bfs("person1", weighted: true, weight_property: "importance")
      {:ok, [%Node{id: "person1"}, ...]}
  """
  def optimized_bfs(start_node_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)
    edge_type = Keyword.get(opts, :edge_type)
    direction = Keyword.get(opts, :direction, :outgoing)
    weighted = Keyword.get(opts, :weighted, false)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)
    default_weight = Keyword.get(opts, :default_weight, 1.0)

    # Use direct ETS access for better performance
    table_name = :graph_os_ets_store

    try do
      # Get the start node directly from ETS
      case :ets.lookup(table_name, {:node, start_node_id}) do
        [{_, start_node}] ->
          # Create a specialized ETS match specification for the traversal
          # This avoids multiple pattern matches and function calls
          edge_pattern = case direction do
            :outgoing ->
              if edge_type do
                {{:edge, :"$1"}, %{source_id: start_node_id, target_id: :"$2", type: edge_type}}
              else
                {{:edge, :"$1"}, %{source_id: start_node_id, target_id: :"$2"}}
              end
            :incoming ->
              if edge_type do
                {{:edge, :"$1"}, %{source_id: :"$2", target_id: start_node_id, type: edge_type}}
              else
                {{:edge, :"$1"}, %{source_id: :"$2", target_id: start_node_id}}
              end
            :both ->
              # For both directions, we need two separate match specs
              # This is simplified and would need to be expanded
              if edge_type do
                {{:edge, :"$1"}, %{source_id: :"$_", target_id: :"$_", type: edge_type}}
              else
                {{:edge, :"$1"}, %{source_id: :"$_", target_id: :"$_"}}
              end
          end

          # Choose the appropriate traversal function based on whether weighted traversal is requested
          results =
            if weighted do
              weighted_bfs_traverse(
                table_name,
                [start_node],
                MapSet.new([start_node_id]),
                edge_pattern,
                max_depth,
                1,
                weight_property,
                prefer_lower_weights,
                default_weight
              )
            else
              optimized_bfs_traverse(
                table_name,
                [start_node],
                MapSet.new([start_node_id]),
                edge_pattern,
                max_depth,
                1
              )
            end

          {:ok, results}

        [] ->
          {:error, :node_not_found}
      end
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  @doc """
  Performs pagerank algorithm on the graph.

  This implementation uses ETS tables for efficient iterative calculation.
  It can also take edge weights into account when calculating influence.

  ## Options

  - `:iterations` - Number of iterations to run (default: 20)
  - `:damping` - Damping factor for the algorithm (default: 0.85)
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:normalize_weights` - Whether to normalize weights (default: true)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.ETS.pagerank(iterations: 30)
      {:ok, %{"node1" => 0.25, "node2" => 0.15, ...}}

      iex> GraphOS.GraphContext.Algorithm.ETS.pagerank(weighted: true, weight_property: "importance")
      {:ok, %{"node1" => 0.28, "node2" => 0.12, ...}}
  """
  def pagerank(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 20)
    damping = Keyword.get(opts, :damping, 0.85)
    weighted = Keyword.get(opts, :weighted, false)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    normalize_weights = Keyword.get(opts, :normalize_weights, true)
    default_weight = Keyword.get(opts, :default_weight, 1.0)
    table_name = :graph_os_ets_store

    try do
      # Get all nodes
      node_pattern = {{:node, :_}, :_}
      nodes = :ets.match_object(table_name, node_pattern)
      |> Enum.map(fn {_, node} -> node end)
      
      # Handle empty graph
      if Enum.empty?(nodes) do
        {:ok, %{}}
      else
        # Create initial ranks (evenly distributed)
        initial_rank = 1.0 / length(nodes)
        ranks = Enum.reduce(nodes, %{}, fn node, acc ->
          Map.put(acc, node.id, initial_rank)
        end)

        # Get all edges for outgoing links calculation
        edge_pattern = {{:edge, :_}, :_}
        edges = :ets.match_object(table_name, edge_pattern)
        |> Enum.map(fn {_, edge} -> edge end)

        # Calculate outgoing counts for each node (possibly weighted)
        {outgoing_counts, edge_weights} =
          if weighted do
            # Calculate edge weights using the direct weight field
            edge_weights = Map.new(edges, fn edge ->
              weight = if Map.has_key?(edge, :weight), do: edge.weight, else: default_weight
              {edge.id, weight}
            end)

            # Normalize weights if requested
            normalized_weights =
              if normalize_weights && !Enum.empty?(edge_weights) do
                Weights.normalize_weights(edge_weights)
              else
                edge_weights
              end

            # Calculate outgoing weights per node
            outgoing_weights = Enum.reduce(edges, %{}, fn edge, acc ->
              weight = Map.get(normalized_weights, edge.id, default_weight)
              Map.update(acc, edge.source, weight, &(&1 + weight))
            end)

            {outgoing_weights, normalized_weights}
          else
            # Simple count for unweighted case
            outgoing_counts = Enum.reduce(edges, %{}, fn edge, acc ->
              Map.update(acc, edge.source, 1, &(&1 + 1))
            end)

            {outgoing_counts, %{}}
          end

        # Run PageRank iterations
        final_ranks = run_pagerank_iterations(
          nodes,
          edges,
          ranks,
          outgoing_counts,
          edge_weights,
          iterations,
          damping,
          weighted
        )

        {:ok, final_ranks}
      end
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  @doc """
  Finds the minimum spanning tree of the graph using Kruskal's algorithm.

  This implementation uses ETS tables for efficient processing and
  supports edge weights.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:default_weight` - Default weight to use when a property is not found (default: 1.0)
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Examples

      iex> GraphOS.GraphContext.Algorithm.ETS.minimum_spanning_tree()
      {:ok, [%Edge{id: "edge1", ...}, ...], 42.5}
  """
  def minimum_spanning_tree(opts \\ []) do
    edge_type = Keyword.get(opts, :edge_type)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    default_weight = Keyword.get(opts, :default_weight, 1.0)
    prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)
    table_name = :graph_os_ets_store

    try do
      # Get all nodes and edges
      node_pattern = {:_, {:node, :_, :_, :_, :_}}
      nodes = :ets.match_object(table_name, node_pattern)
      |> Enum.map(fn {_, node} -> node end)

      # Get all edges and filter by type if needed
      edge_pattern = {:_, {:edge, :_, :_, :_, :_, :_}}
      edges = :ets.match_object(table_name, edge_pattern)
      |> Enum.map(fn {_, edge} -> edge end)
      |> (fn edges ->
        if edge_type do
          Enum.filter(edges, fn edge -> edge.type == edge_type end)
        else
          edges
        end
      end).()

      # Get edge weights
      edge_weights = Map.new(edges, fn edge ->
        {edge.id, Weights.get_edge_weight(edge, weight_property, default_weight)}
      end)

      # Sort edges by weight (ascending for minimize, descending for maximize)
      sorted_edges =
        if prefer_lower_weights do
          Enum.sort_by(edges, fn edge -> Map.get(edge_weights, edge.id, default_weight) end)
        else
          Enum.sort_by(edges, fn edge -> Map.get(edge_weights, edge.id, default_weight) end, :desc)
        end

      # Apply Kruskal's algorithm
      {mst_edges, total_weight} = kruskal_mst(nodes, sorted_edges, edge_weights)

      {:ok, mst_edges, total_weight}
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  # Private helper functions

  defp optimized_bfs_traverse(_table_name, current_level, _visited, _edge_pattern, max_depth, current_depth)
       when current_depth > max_depth do
    # Stop at max depth
    current_level
  end

  defp optimized_bfs_traverse(table_name, current_level, visited, edge_pattern, max_depth, current_depth) do
    # Find all neighbors of the current level nodes
    next_level = Enum.flat_map(current_level, fn node ->
      # Find edges connected to this node
      case direction_from_pattern(edge_pattern) do
        :outgoing ->
          # Find all outgoing edges from this node
          outgoing_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :source_id, node.id))
          :ets.match_object(table_name, outgoing_pattern)
          |> Enum.map(fn {_, edge} -> edge.target_id end)

        :incoming ->
          # Find all incoming edges to this node
          incoming_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :target_id, node.id))
          :ets.match_object(table_name, incoming_pattern)
          |> Enum.map(fn {_, edge} -> edge.source_id end)

        :both ->
          # Find both outgoing and incoming edges
          outgoing_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :source_id, node.id))
          incoming_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :target_id, node.id))

          outgoing_ids = :ets.match_object(table_name, outgoing_pattern)
                         |> Enum.map(fn {_, edge} -> edge.target_id end)

          incoming_ids = :ets.match_object(table_name, incoming_pattern)
                         |> Enum.map(fn {_, edge} -> edge.source_id end)

          outgoing_ids ++ incoming_ids
      end
    end)

    # Filter for unvisited nodes and look them up
    unvisited_ids = next_level
                    |> Enum.uniq()
                    |> Enum.reject(fn id -> MapSet.member?(visited, id) end)

    unvisited_nodes = Enum.map(unvisited_ids, fn id ->
      case :ets.lookup(table_name, {:node, id}) do
        [{_, node}] -> node
        [] -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    # If no new nodes, we're done
    if Enum.empty?(unvisited_nodes) do
      current_level
    else
      # Update visited set
      new_visited = Enum.reduce(unvisited_nodes, visited, fn node, acc ->
        MapSet.put(acc, node.id)
      end)

      # Continue traversal with next level
      optimized_bfs_traverse(
        table_name,
        unvisited_nodes,
        new_visited,
        edge_pattern,
        max_depth,
        current_depth + 1
      ) ++ current_level
    end
  end

  # Weighted BFS traversal that prioritizes edges based on weights
  defp weighted_bfs_traverse(_table_name, current_level, _visited, _edge_pattern, max_depth, current_depth, _, _, _)
       when current_depth > max_depth do
    # Stop at max depth
    current_level
  end

  defp weighted_bfs_traverse(table_name, current_level, visited, edge_pattern, max_depth, current_depth,
                             weight_property, prefer_lower_weights, default_weight) do
    # Find all neighbors of the current level nodes with their edge weights
    neighbors_with_weights = Enum.flat_map(current_level, fn node ->
      # Find edges connected to this node based on direction
      edges = case direction_from_pattern(edge_pattern) do
        :outgoing ->
          outgoing_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :source_id, node.id))
          :ets.match_object(table_name, outgoing_pattern)

        :incoming ->
          incoming_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :target_id, node.id))
          :ets.match_object(table_name, incoming_pattern)

        :both ->
          outgoing_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :source_id, node.id))
          incoming_pattern = put_elem(edge_pattern, 1, Map.put(elem(edge_pattern, 1), :target_id, node.id))
          :ets.match_object(table_name, outgoing_pattern) ++ :ets.match_object(table_name, incoming_pattern)
      end

      # Extract target nodes and weights
      Enum.map(edges, fn {_, edge} ->
        target_id = case direction_from_pattern(edge_pattern) do
          :outgoing -> edge.target_id
          :incoming -> edge.source_id
          :both ->
            if edge.source_id == node.id, do: edge.target_id, else: edge.source_id
        end

        # Get weight from the edge
        weight = if Map.has_key?(edge, :weight) do
          edge.weight
        else
          default_weight
        end
        
        {target_id, weight, node.id}  # Include source node ID for reference
      end)
    end)

    # Filter out visited nodes
    unvisited_with_weights = neighbors_with_weights
                          |> Enum.reject(fn {id, _, _} -> MapSet.member?(visited, id) end)
                          |> Enum.uniq_by(fn {id, _, _} -> id end)  # Only keep unique target nodes

    # If prefer_lower_weights is true, sort by ascending weight, otherwise by descending
    sorted_neighbors =
      if prefer_lower_weights do
        Enum.sort_by(unvisited_with_weights, fn {_, weight, _} -> weight end)
      else
        Enum.sort_by(unvisited_with_weights, fn {_, weight, _} -> weight end, :desc)
      end

    # Get the node objects
    sorted_nodes = sorted_neighbors
                 |> Enum.map(fn {id, _, _} -> id end)
                 |> Enum.map(fn id ->
                     case :ets.lookup(table_name, {:node, id}) do
                       [{_, node}] -> node
                       [] -> nil
                     end
                   end)
                 |> Enum.reject(&is_nil/1)

    # If no new nodes, we're done
    if Enum.empty?(sorted_nodes) do
      current_level
    else
      # Update visited set
      new_visited = Enum.reduce(sorted_nodes, visited, fn node, acc ->
        MapSet.put(acc, node.id)
      end)

      # Continue traversal with next level
      # Note: We append current_level to the result to ensure that nodes are added in BFS order
      sorted_nodes ++ weighted_bfs_traverse(
        table_name,
        sorted_nodes,
        new_visited,
        edge_pattern,
        max_depth,
        current_depth + 1,
        weight_property,
        prefer_lower_weights,
        default_weight
      )
    end
  end

  defp direction_from_pattern(pattern) do
    # Extract direction from edge pattern
    # This is a bit of a hack to determine the direction from the pattern
    case elem(pattern, 1) do
      %{source_id: node_id, target_id: :"$2"} when not is_atom(node_id) -> :outgoing
      %{source_id: :"$2", target_id: node_id} when not is_atom(node_id) -> :incoming
      _ -> :both
    end
  end

  defp run_pagerank_iterations(_nodes, _edges, ranks, _outgoing_counts, _edge_weights, iterations, _damping, _weighted)
       when iterations <= 0 do
    ranks
  end

  defp run_pagerank_iterations(nodes, edges, ranks, outgoing_counts, edge_weights, iterations, damping, weighted) do
    # Calculate new ranks for this iteration
    new_ranks = Enum.reduce(nodes, %{}, fn node, acc ->
      # Sum of incoming ranks
      incoming_sum = Enum.reduce(edges, 0.0, fn edge, sum ->
        if edge.target == node.id do
          # Get source rank
          source_rank = Map.get(ranks, edge.source, 0.0)

          if weighted do
            # Get edge weight and outgoing weight sum
            edge_weight = Map.get(edge_weights, edge.id, 1.0)
            outgoing_weight_sum = Map.get(outgoing_counts, edge.source, 0.0)

            if outgoing_weight_sum > 0 do
              sum + (source_rank * edge_weight / outgoing_weight_sum)
            else
              sum
            end
          else
            # Unweighted version - just use counts
            source_outgoing = Map.get(outgoing_counts, edge.source, 0)

            if source_outgoing > 0 do
              sum + (source_rank / source_outgoing)
            else
              sum
            end
          end
        else
          sum
        end
      end)

      # Calculate new rank with damping factor
      new_rank = (1.0 - damping) / length(nodes) + damping * incoming_sum

      # Store the new rank
      Map.put(acc, node.id, new_rank)
    end)

    # Continue with next iteration
    if iterations <= 1 do
      new_ranks
    else
      run_pagerank_iterations(
        nodes,
        edges,
        new_ranks,
        outgoing_counts,
        edge_weights,
        iterations - 1,
        damping,
        weighted
      )
    end
  end

  # Kruskal's algorithm implementation for MST
  defp kruskal_mst(nodes, sorted_edges, edge_weights) do
    # Initialize disjoint set with each node in its own set
    disjoint_set = Enum.reduce(nodes, %{}, fn node, acc ->
      Map.put(acc, node.id, node.id)
    end)

    # Run Kruskal's algorithm
    do_kruskal_mst(sorted_edges, edge_weights, disjoint_set, [], 0)
  end

  defp do_kruskal_mst([], _edge_weights, _disjoint_set, mst_edges, total_weight) do
    # No more edges to process
    {Enum.reverse(mst_edges), total_weight}
  end

  defp do_kruskal_mst([edge | rest], edge_weights, disjoint_set, mst_edges, total_weight) do
    # Find representatives of the sets for the source and target nodes
    source_rep = find_set(disjoint_set, edge.source_id)
    target_rep = find_set(disjoint_set, edge.target_id)

    if source_rep != target_rep do
      # Edge connects different components, add it to MST
      new_disjoint_set = union_sets(disjoint_set, source_rep, target_rep)
      edge_weight = Map.get(edge_weights, edge.id, 1.0)

      do_kruskal_mst(
        rest,
        edge_weights,
        new_disjoint_set,
        [edge | mst_edges],
        total_weight + edge_weight
      )
    else
      # Edge would create a cycle, skip it
      do_kruskal_mst(rest, edge_weights, disjoint_set, mst_edges, total_weight)
    end
  end

  # Disjoint set operations for Kruskal's algorithm

  defp find_set(disjoint_set, node_id) do
    case Map.get(disjoint_set, node_id) do
      ^node_id -> node_id
      parent_id -> find_set(disjoint_set, parent_id)
    end
  end

  defp union_sets(disjoint_set, rep1, rep2) do
    # Merge the two sets by making one a parent of the other
    Map.put(disjoint_set, rep2, rep1)
  end
end
