defmodule GraphOS.Graph.Store.CrossQuery do
  @moduledoc """
  Provides cross-store query capabilities for comparing and analyzing
  data across multiple graph stores.
  """
  
  require Logger
  
  @doc """
  Execute a query across multiple stores.
  
  ## Parameters
  
  - `main_store` - The primary store to query
  - `additional_stores` - List of additional stores to query
  - `query` - The query to execute
  - `options` - Query options
  
  ## Options
  
  - `:merge_results` - Whether to merge results into a single list (default: false)
  - `:transform` - Optional function to transform results before returning
  
  ## Returns
  
  A map with results from each store, or a merged list if `:merge_results` is true.
  """
  def execute(main_store, additional_stores, query, options \\ []) do
    # Query main store
    main_results = case GraphOS.Graph.Store.Server.query(main_store, query, options) do
      {:ok, results} -> results
      {:error, reason} ->
        Logger.warn("Error querying main store #{inspect(main_store)}: #{inspect(reason)}")
        []
    end
    
    # Query additional stores
    additional_results =
      additional_stores
      |> Enum.map(fn store ->
        case GraphOS.Graph.Store.Server.query(store, query, options) do
          {:ok, results} -> {store, results}
          {:error, reason} ->
            Logger.warn("Error querying store #{inspect(store)}: #{inspect(reason)}")
            {store, []}
        end
      end)
      |> Enum.into(%{})
    
    # Return format depends on options
    if Keyword.get(options, :merge_results, false) do
      # Merge all results into a single list
      all_results = [main_results | Map.values(additional_results)] |> List.flatten()
      
      # Apply transformation if provided
      case Keyword.get(options, :transform) do
        nil -> {:ok, all_results}
        transform_fun when is_function(transform_fun) -> {:ok, transform_fun.(all_results)}
      end
    else
      # Return as a map with store identifiers
      results = %{
        main_store => main_results,
        additional: additional_results
      }
      
      # Apply transformation if provided
      case Keyword.get(options, :transform) do
        nil -> {:ok, results}
        transform_fun when is_function(transform_fun) -> {:ok, transform_fun.(results)}
      end
    end
  end
  
  @doc """
  Compare two stores and find differences.
  
  ## Parameters
  
  - `store1` - First store to compare
  - `store2` - Second store to compare
  - `options` - Comparison options
  
  ## Options
  
  - `:node_types` - Types of nodes to compare (default: all)
  - `:edge_types` - Types of edges to compare (default: all)
  - `:include_attributes` - Whether to compare node/edge attributes (default: true)
  
  ## Returns
  
  A map containing added, removed, and modified nodes and edges.
  """
  def diff(store1, store2, options \\ []) do
    Logger.info("Comparing stores: #{inspect(store1)} and #{inspect(store2)}")
    
    # Get all nodes from both stores
    {:ok, store1_nodes} = GraphOS.Graph.Store.Server.query(store1, %{type: :node}, [])
    {:ok, store2_nodes} = GraphOS.Graph.Store.Server.query(store2, %{type: :node}, [])
    
    # Get all edges from both stores
    {:ok, store1_edges} = GraphOS.Graph.Store.Server.query(store1, %{type: :edge}, [])
    {:ok, store2_edges} = GraphOS.Graph.Store.Server.query(store2, %{type: :edge}, [])
    
    # Filter by node/edge types if specified
    store1_nodes = filter_by_types(store1_nodes, Keyword.get(options, :node_types))
    store2_nodes = filter_by_types(store2_nodes, Keyword.get(options, :node_types))
    store1_edges = filter_by_types(store1_edges, Keyword.get(options, :edge_types))
    store2_edges = filter_by_types(store2_edges, Keyword.get(options, :edge_types))
    
    # Compare nodes
    {added_nodes, removed_nodes, modified_nodes} = compare_elements(
      store1_nodes, 
      store2_nodes, 
      Keyword.get(options, :include_attributes, true)
    )
    
    # Compare edges
    {added_edges, removed_edges, modified_edges} = compare_elements(
      store1_edges, 
      store2_edges, 
      Keyword.get(options, :include_attributes, true)
    )
    
    # Return diff results
    {:ok, %{
      nodes: %{
        added: added_nodes,
        removed: removed_nodes,
        modified: modified_nodes
      },
      edges: %{
        added: added_edges,
        removed: removed_edges,
        modified: modified_edges
      }
    }}
  end
  
  @doc """
  Execute a query across multiple branch stores for a specific repository.
  
  ## Parameters
  
  - `query` - The query to execute
  - `repo_path` - Repository path to limit the query to
  - `opts` - Options for the query
  
  ## Options
  
  - `:branches` - List of branches to query (default: all branches)
  - `:merge_results` - Whether to merge results into a single list (default: false)
  
  ## Returns
  
  A map containing results from each branch, or a single merged list.
  """
  def query_across_branches(query, repo_path, opts \\ []) do
    # Get all branch stores for this repository
    branch_stores = get_branch_stores(repo_path)
    
    # Filter by branch names if specified
    branch_stores = case Keyword.get(opts, :branches) do
      nil -> branch_stores
      branches when is_list(branches) ->
        Map.take(branch_stores, branches)
    end
    
    if map_size(branch_stores) == 0 do
      {:error, "No branch stores found for repository #{repo_path}"}
    else
      # Convert to list of {branch_name, store_pid}
      stores_list = Enum.map(branch_stores, fn {branch, store_pid} -> {branch, store_pid} end)
      
      # Query each branch store
      results = Enum.map(stores_list, fn {branch, store_pid} ->
        case GraphOS.Graph.Store.Server.query(store_pid, query, opts) do
          {:ok, branch_results} -> {branch, branch_results}
          {:error, reason} ->
            Logger.warn("Error querying branch #{branch}: #{inspect(reason)}")
            {branch, []}
        end
      end)
      |> Enum.into(%{})
      
      # Return format depends on options
      if Keyword.get(opts, :merge_results, false) do
        # Merge all results into a single list with branch information
        all_results = 
          Enum.flat_map(results, fn {branch, branch_results} ->
            Enum.map(branch_results, fn result -> Map.put(result, :branch, branch) end)
          end)
          
        {:ok, all_results}
      else
        # Return as a map with branch identifiers
        {:ok, results}
      end
    end
  end
  
  @doc """
  Compare code structure between two branches in a repository.
  
  ## Parameters
  
  - `repo_path` - Repository path
  - `branch1` - First branch name
  - `branch2` - Second branch name
  - `opts` - Options for comparison
  
  ## Returns
  
  A diff of nodes and edges between the two branches.
  """
  def compare_branches(repo_path, branch1, branch2, opts \\ []) do
    # Get the stores for both branches
    branch_stores = get_branch_stores(repo_path)
    
    with %{} = stores when map_size(stores) > 0 <- branch_stores,
         store1 when not is_nil(store1) <- Map.get(stores, branch1),
         store2 when not is_nil(store2) <- Map.get(stores, branch2) do
      
      # Compare the stores
      diff(store1, store2, opts)
    else
      _ -> {:error, "Could not find stores for branches #{branch1} and #{branch2} in repository #{repo_path}"}
    end
  end
  
  # Private helper functions
  
  defp filter_by_types(elements, nil), do: elements
  defp filter_by_types(elements, types) when is_list(types) do
    Enum.filter(elements, fn element ->
      element.type in types
    end)
  end
  
  defp compare_elements(elements1, elements2, include_attributes) do
    # Create maps for faster lookup
    elements1_map = elements1 |> Enum.map(& {&1.id, &1}) |> Enum.into(%{})
    elements2_map = elements2 |> Enum.map(& {&1.id, &1}) |> Enum.into(%{})
    
    # Find added elements (in elements2 but not in elements1)
    added = elements2
      |> Enum.filter(fn e -> not Map.has_key?(elements1_map, e.id) end)
    
    # Find removed elements (in elements1 but not in elements2)
    removed = elements1
      |> Enum.filter(fn e -> not Map.has_key?(elements2_map, e.id) end)
    
    # Find modified elements (in both but with different attributes)
    modified = if include_attributes do
      # Get elements in both lists
      common_ids = MapSet.intersection(
        MapSet.new(Map.keys(elements1_map)),
        MapSet.new(Map.keys(elements2_map))
      )
      
      # Find elements with different attributes
      Enum.filter(MapSet.to_list(common_ids), fn id ->
        e1 = Map.get(elements1_map, id)
        e2 = Map.get(elements2_map, id)
        # Compare excluding id field and some metadata
        compare_attributes(e1, e2)
      end)
      |> Enum.map(fn id ->
        # Return both versions for comparison
        %{
          id: id,
          before: Map.get(elements1_map, id),
          after: Map.get(elements2_map, id)
        }
      end)
    else
      []
    end
    
    {added, removed, modified}
  end
  
  defp compare_attributes(e1, e2) do
    # Extract key fields to compare
    keys_to_compare = Map.keys(e1) -- [:id, :__metadata__]
    
    # Check if any attribute is different
    Enum.any?(keys_to_compare, fn key ->
      Map.get(e1, key) != Map.get(e2, key)
    end)
  end
  
  # Private helper to get all branch stores for a repository
  defp get_branch_stores(repo_path) do
    # Get all stores from the registry
    Registry.select(GraphOS.Graph.StoreRegistry, [{{:_, :_, :_}, [], [:'$_']}])
    |> Enum.map(fn {name, pid, _} -> {name, pid} end)
    |> Enum.filter(fn {name, _} ->
      # Filter stores that match our repository and are branch stores
      is_binary(name) && 
      String.starts_with?(to_string(name), "GraphOS.Core.CodeGraph.Store:#{repo_path}:")
    end)
    |> Enum.map(fn {name, pid} ->
      # Extract branch name from store name
      branch = String.replace_prefix(to_string(name), "GraphOS.Core.CodeGraph.Store:#{repo_path}:", "")
      {branch, pid}
    end)
    |> Enum.into(%{})
  end
end
