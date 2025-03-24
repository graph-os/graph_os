defmodule GraphOS.Store.Algorithm.ETS do
  @moduledoc """
  Optimized graph algorithm implementations for the ETS storage backend.

  This module contains specialized implementations of graph algorithms
  that take advantage of ETS-specific optimizations for better performance.
  """

  alias GraphOS.Store
  alias GraphOS.Store.{Query, Node, Edge}
  alias GraphOS.Store.Algorithm.Weights

  @doc """
  Processes a traversal query using BFS algorithm.

  This implementation is optimized for performance with the ETS adapter.

  ## Options

  - `max_depth` - Maximum traversal depth (default: 10)
  - `edge_type` - Filter edges by type
  - `direction` - Direction of traversal (default: :outgoing)
  - `weighted` - Whether to consider edge weights (default: false)
  - `weight_property` - The property name to use for edge weights (default: "weight")
  - `prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Returns

  - `{:ok, [%Node{}, ...]}` - List of traversed nodes
  - `{:error, reason}` - Error with reason
  """
  @spec process_traverse_query(String.t(), keyword()) ::
          {:ok, list(Node.t())} | {:error, term()}
  def process_traverse_query(start_node_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)
    edge_type = Keyword.get(opts, :edge_type)
    direction = Keyword.get(opts, :direction, :outgoing)
    weighted = Keyword.get(opts, :weighted, false)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)
    default_weight = Keyword.get(opts, :default_weight, 1.0)

    try do
      # Get the start node
      case Store.execute(Query.get(:node, start_node_id)) do
        {:ok, start_node} ->
          # Build a filter for connected edges
          filter =
            case direction do
              :outgoing -> %{source: start_node_id}
              :incoming -> %{target: start_node_id}
              # No filter for bi-directional, need custom handling
              :both -> %{}
            end

          # Add type filter if specified
          _filter = if edge_type, do: Map.put(filter, :type, edge_type), else: filter

          # Create a traversal context instead of using direct ETS access
          traversal_ctx = %{
            start_node: start_node,
            visited: MapSet.new([start_node_id]),
            result: [start_node],
            max_depth: max_depth,
            edge_type: edge_type,
            direction: direction,
            weighted: weighted,
            weight_property: weight_property,
            prefer_lower_weights: prefer_lower_weights,
            default_weight: default_weight
          }

          # Choose the appropriate traversal function based on whether weighted traversal is requested
          result =
            if weighted do
              do_weighted_traverse(traversal_ctx, [start_node], 1)
            else
              do_traverse(traversal_ctx, [start_node], 1)
            end

          {:ok, result}

        {:error, _} ->
          {:error, :node_not_found}
      end
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  # Recursive traversal for unweighted BFS
  defp do_traverse(_ctx, [], _depth), do: []
  defp do_traverse(ctx, _current_nodes, depth) when depth > ctx.max_depth, do: ctx.result

  defp do_traverse(ctx, current_nodes, depth) do
    # For each current node, get connected nodes we haven't visited yet
    {next_nodes, visited, result} =
      Enum.reduce(current_nodes, {[], ctx.visited, ctx.result}, fn node,
                                                                   {next_acc, visited_acc,
                                                                    result_acc} ->
        # Get connected node IDs based on direction
        connected_ids = get_connected_node_ids(node.id, ctx.direction, ctx.edge_type)

        # Filter out already visited nodes
        new_ids = Enum.reject(connected_ids, &MapSet.member?(visited_acc, &1))

        # Get the actual nodes for new IDs
        new_nodes =
          Enum.map(new_ids, fn id ->
            {:ok, node} = Store.execute(Query.get(:node, id))
            node
          end)

        # Update accumulators
        {
          next_acc ++ new_nodes,
          Enum.reduce(new_ids, visited_acc, &MapSet.put(&2, &1)),
          result_acc ++ new_nodes
        }
      end)

    # Recursively process next level
    updated_ctx = %{ctx | visited: visited, result: result}
    result ++ do_traverse(updated_ctx, next_nodes, depth + 1)
  end

  # Recursive traversal for weighted BFS
  defp do_weighted_traverse(_ctx, [], _depth), do: []
  defp do_weighted_traverse(ctx, _current_nodes, depth) when depth > ctx.max_depth, do: ctx.result

  defp do_weighted_traverse(ctx, current_nodes, depth) do
    # Similar to unweighted traversal but considers edge weights
    {next_nodes, visited, result} =
      Enum.reduce(current_nodes, {[], ctx.visited, ctx.result}, fn node,
                                                                   {next_acc, visited_acc,
                                                                    result_acc} ->
        # Get connected edges with weights
        connected_edges = get_connected_edges(node.id, ctx.direction, ctx.edge_type)

        # Extract target IDs and weights
        targets_with_weights =
          Enum.map(connected_edges, fn edge ->
            target_id = if ctx.direction == :outgoing, do: edge.target, else: edge.source
            weight = get_edge_weight(edge, ctx.weight_property, ctx.default_weight)
            {target_id, weight}
          end)

        # Filter out already visited nodes
        new_targets =
          Enum.reject(targets_with_weights, fn {id, _} -> MapSet.member?(visited_acc, id) end)

        # Sort by weight (prefer lower or higher based on option)
        sorted_targets =
          if ctx.prefer_lower_weights do
            Enum.sort_by(new_targets, fn {_, weight} -> weight end)
          else
            Enum.sort_by(new_targets, fn {_, weight} -> -weight end)
          end

        # Get the actual nodes for new IDs
        new_ids = Enum.map(sorted_targets, fn {id, _} -> id end)

        new_nodes =
          Enum.map(new_ids, fn id ->
            {:ok, node} = Store.execute(Query.get(:node, id))
            node
          end)

        # Update accumulators
        {
          next_acc ++ new_nodes,
          Enum.reduce(new_ids, visited_acc, &MapSet.put(&2, &1)),
          result_acc ++ new_nodes
        }
      end)

    # Recursively process next level
    updated_ctx = %{ctx | visited: visited, result: result}
    result ++ do_weighted_traverse(updated_ctx, next_nodes, depth + 1)
  end

  # Helper to get connected node IDs
  defp get_connected_node_ids(node_id, direction, edge_type) do
    filter =
      case direction do
        :outgoing ->
          %{source: node_id}

        :incoming ->
          %{target: node_id}

        :both ->
          # For bidirectional, we need to fetch both outgoing and incoming
          outgoing = get_connected_node_ids(node_id, :outgoing, edge_type)
          incoming = get_connected_node_ids(node_id, :incoming, edge_type)
          # Return combined results
          MapSet.to_list(MapSet.union(MapSet.new(outgoing), MapSet.new(incoming)))
      end

    # Add type filter if specified
    _filter = if edge_type, do: Map.put(filter, :type, edge_type), else: filter

    # Query edges and extract target IDs
    {:ok, edges} = Store.execute(Query.list(:edge, filter))

    # Extract target or source based on direction
    Enum.map(edges, fn edge ->
      case direction do
        :outgoing -> edge.target
        :incoming -> edge.source
        # Bidirectional handled above
        _ -> nil
      end
    end)
  end

  # Helper to get connected edges
  defp get_connected_edges(node_id, direction, edge_type) do
    filter =
      case direction do
        :outgoing ->
          %{source: node_id}

        :incoming ->
          %{target: node_id}

        :both ->
          # For bidirectional, we need to fetch both outgoing and incoming
          outgoing = get_connected_edges(node_id, :outgoing, edge_type)
          incoming = get_connected_edges(node_id, :incoming, edge_type)
          # Return combined results
          outgoing ++ incoming
      end

    # Add type filter if specified
    _filter = if edge_type, do: Map.put(filter, :type, edge_type), else: filter

    # Query edges
    {:ok, edges} = Store.execute(Query.list(:edge, filter))
    edges
  end

  # Helper to get edge weight
  defp get_edge_weight(edge, weight_property, default_weight) do
    case edge.data do
      %{^weight_property => weight} when is_number(weight) -> weight
      _ -> default_weight
    end
  end

  @doc """
  Processes a pagerank query.

  ## Options

  - `:iterations` - Number of iterations to run (default: 20)
  - `:damping` - Damping factor for the algorithm (default: 0.85)
  - `:weighted` - Whether to consider edge weights (default: false)
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:normalize_weights` - Whether to normalize weights (default: true)

  ## Returns

  - `{:ok, %{"node_id" => rank, ...}}` - Map of node IDs to ranks
  - `{:error, reason}` - Error with reason
  """
  @spec process_pagerank_query(keyword()) ::
          {:ok, map()} | {:error, term()}
  def process_pagerank_query(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 20)
    damping = Keyword.get(opts, :damping, 0.85)
    weighted = Keyword.get(opts, :weighted, false)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    normalize_weights = Keyword.get(opts, :normalize_weights, true)
    default_weight = Keyword.get(opts, :default_weight, 1.0)

    try do
      # Get all nodes
      {:ok, nodes} = Store.execute(Query.list(:node))

      # Handle empty graph
      if Enum.empty?(nodes) do
        {:ok, %{}}
      else
        # Create initial ranks (evenly distributed)
        initial_rank = 1.0 / length(nodes)
        ranks = Enum.reduce(nodes, %{}, fn node, acc -> Map.put(acc, node.id, initial_rank) end)

        # Get all edges
        {:ok, edges} = Store.execute(Query.list(:edge))

        # Calculate outgoing counts for each node (possibly weighted)
        {outgoing_counts, edge_weights} =
          if weighted do
            # Calculate edge weights based on the specified property
            edge_weights =
              Enum.reduce(edges, %{}, fn edge, acc ->
                weight = get_edge_weight(edge, weight_property, default_weight)
                Map.put(acc, edge.id, weight)
              end)

            # Normalize weights if requested
            normalized_weights =
              if normalize_weights && !Enum.empty?(edge_weights) do
                Weights.normalize_weights(edge_weights)
              else
                edge_weights
              end

            # Calculate outgoing weights per node
            outgoing_weights =
              Enum.reduce(edges, %{}, fn edge, acc ->
                weight = Map.get(normalized_weights, edge.id, default_weight)
                Map.update(acc, edge.source, weight, &(&1 + weight))
              end)

            {outgoing_weights, normalized_weights}
          else
            # Simple count for unweighted case
            outgoing_counts =
              Enum.reduce(edges, %{}, fn edge, acc ->
                Map.update(acc, edge.source, 1, &(&1 + 1))
              end)

            {outgoing_counts, %{}}
          end

        # Run PageRank iterations
        final_ranks =
          pagerank_iterations(
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

  # Run PageRank algorithm iterations
  defp pagerank_iterations(
         nodes,
         edges,
         ranks,
         outgoing_counts,
         edge_weights,
         iterations,
         damping,
         weighted
       ) do
    # Implement PageRank iteration logic
    # This is a simplified version that would need to be expanded with the actual algorithm
    Enum.reduce(1..iterations, ranks, fn _i, current_ranks ->
      # Calculate new ranks for this iteration
      new_ranks =
        calculate_iteration_ranks(
          nodes,
          edges,
          current_ranks,
          outgoing_counts,
          edge_weights,
          damping,
          weighted
        )

      # Check for convergence
      if pagerank_converged?(current_ranks, new_ranks) do
        # End early if converged
        throw({:converged, new_ranks})
      else
        new_ranks
      end
    end)
  catch
    {:converged, final_ranks} -> final_ranks
  end

  # Calculate ranks for a single iteration
  defp calculate_iteration_ranks(
         nodes,
         edges,
         current_ranks,
         outgoing_counts,
         edge_weights,
         damping,
         weighted
       ) do
    # Initialize with base probability from random jumps (1-d)/N
    node_count = length(nodes)
    base_rank = (1 - damping) / node_count

    # Start with base rank for all nodes
    base_ranks =
      Enum.reduce(nodes, %{}, fn node, acc ->
        Map.put(acc, node.id, base_rank)
      end)

    # Add rank contributions from incoming links
    Enum.reduce(edges, base_ranks, fn edge, acc ->
      source_id = edge.source
      target_id = edge.target

      # Skip if source has no outgoing links
      case Map.get(outgoing_counts, source_id) do
        nil ->
          acc

        0 ->
          acc

        outgoing ->
          # Calculate contribution based on source rank and outgoing count
          source_rank = Map.get(current_ranks, source_id, 0)

          # For weighted PageRank, use edge weight
          contribution =
            if weighted do
              edge_weight = Map.get(edge_weights, edge.id, 1.0)
              damping * source_rank * (edge_weight / outgoing)
            else
              damping * source_rank / outgoing
            end

          # Add contribution to target's rank
          Map.update(acc, target_id, contribution, &(&1 + contribution))
      end
    end)
  end

  # Check if PageRank has converged
  defp pagerank_converged?(old_ranks, new_ranks, threshold \\ 0.0001) do
    # Calculate sum of absolute differences
    diff_sum =
      Enum.reduce(old_ranks, 0, fn {node_id, old_rank}, sum ->
        new_rank = Map.get(new_ranks, node_id, 0)
        sum + abs(new_rank - old_rank)
      end)

    # Consider converged if average difference is below threshold
    diff_sum / map_size(old_ranks) < threshold
  end

  @doc """
  Processes a minimum spanning tree query.

  Finds the minimum spanning tree of the graph using Kruskal's algorithm.

  ## Options

  - `:edge_type` - Filter edges by type
  - `:weight_property` - The property name to use for edge weights (default: "weight")
  - `:default_weight` - Default weight to use when a property is not found (default: 1.0)
  - `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

  ## Returns

  - `{:ok, [%Edge{}, ...], total_weight}` - Tree edges and total weight
  - `{:error, reason}` - Error with reason
  """
  @spec process_mst_query(keyword()) ::
          {:ok, list(Edge.t()), number()} | {:error, term()}
  def process_mst_query(opts \\ []) do
    edge_type = Keyword.get(opts, :edge_type)
    weight_property = Keyword.get(opts, :weight_property, "weight")
    default_weight = Keyword.get(opts, :default_weight, 1.0)
    prefer_lower_weights = Keyword.get(opts, :prefer_lower_weights, true)

    try do
      # Get all nodes
      {:ok, nodes} = Store.execute(Query.list(:node))

      # Create filter for edges
      edge_filter = if edge_type, do: %{type: edge_type}, else: %{}

      # Get all edges
      {:ok, edges} = Store.execute(Query.list(:edge, edge_filter))

      # Apply Kruskal's algorithm to find MST
      {tree_edges, total_weight} =
        kruskal_mst(
          nodes,
          edges,
          weight_property,
          default_weight,
          prefer_lower_weights
        )

      {:ok, tree_edges, total_weight}
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  # Implement Kruskal's algorithm for Minimum Spanning Tree
  defp kruskal_mst(nodes, edges, weight_property, default_weight, prefer_lower_weights) do
    # Sort edges by weight
    sorted_edges =
      Enum.sort_by(edges, fn edge ->
        weight = get_edge_weight(edge, weight_property, default_weight)
        if prefer_lower_weights, do: weight, else: -weight
      end)

    # Create disjoint set for nodes
    node_sets =
      Enum.reduce(nodes, %{}, fn node, acc ->
        Map.put(acc, node.id, [node.id])
      end)

    # Apply Kruskal's algorithm
    {tree_edges, total_weight, _} =
      Enum.reduce(sorted_edges, {[], 0, node_sets}, fn edge, {tree, weight_sum, sets} ->
        source_id = edge.source
        target_id = edge.target

        # Find sets containing source and target
        source_set = find_set(sets, source_id)
        target_set = find_set(sets, target_id)

        # If nodes are in different sets, add edge to MST
        if source_set != target_set do
          # Union the sets
          merged_sets = union_sets(sets, source_set, target_set)

          # Add edge to MST
          edge_weight = get_edge_weight(edge, weight_property, default_weight)
          {[edge | tree], weight_sum + edge_weight, merged_sets}
        else
          # Skip edge to avoid cycles
          {tree, weight_sum, sets}
        end
      end)

    {tree_edges, total_weight}
  end

  # Find the set containing the node
  defp find_set(sets, node_id) do
    Enum.find_value(sets, fn {set_id, members} ->
      if node_id in members, do: set_id, else: nil
    end)
  end

  # Union two sets
  defp union_sets(sets, set1_id, set2_id) do
    set1 = Map.get(sets, set1_id, [])
    set2 = Map.get(sets, set2_id, [])

    # Remove the old sets
    sets = Map.drop(sets, [set1_id, set2_id])

    # Create the merged set
    merged = set1 ++ set2

    # Add the merged set with set1's ID
    Map.put(sets, set1_id, merged)
  end
end
