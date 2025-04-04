defmodule GraphOS.Store.Query.Planner do
  @moduledoc """
  Query planner and optimizer for GraphOS.
  
  This module provides functionality to analyze queries, optimize their execution plan,
  and compile match specifications for common query patterns.
  """
  
  require Logger
  
  @doc """
  Optimizes a query plan based on the provided query spec and store metadata.
  
  ## Parameters
  
  - `store_ref` - The store reference
  - `query_spec` - The query specification to optimize
  - `opts` - Additional options for optimization
  
  ## Returns
  
  - `{:ok, query_plan}` - The optimized query plan
  - `{:error, reason}` - Error with reason
  """
  def optimize(store_ref, query_spec, opts \\ []) do
    # Start with the initial query spec
    initial_plan = %{
      store_ref: store_ref,
      operations: query_spec.operations,
      filters: query_spec.filters,
      pattern: nil,  # Will be populated with compiled match spec
      estimated_cost: :infinity,
      use_indices: []
    }
    
    # Generate possible execution plans
    plans = generate_plans(initial_plan, opts)
    
    # Select the best plan based on estimated cost
    best_plan = Enum.min_by(plans, fn plan -> plan.estimated_cost end)
    
    {:ok, best_plan}
  end
  
  @doc """
  Executes a query plan against the store.
  
  ## Parameters
  
  - `plan` - The query plan to execute
  - `opts` - Additional execution options
  
  ## Returns
  
  - `{:ok, results}` - The query results
  - `{:error, reason}` - Error with reason
  """
  def execute_plan(plan, opts \\ []) do
    # Access the store and entity type
    store_ref = plan.store_ref
    entity_type = Keyword.get(opts, :entity_type)
    
    # Use compiled match pattern if available, otherwise build one on-the-fly
    pattern = plan.pattern || build_match_pattern(plan.filters)
    
    # Decide which access path to use based on the plan
    results = cond do
      # If we're using a type index for edges
      :edge_type in plan.use_indices && entity_type == :edge ->
        # Extract the type value from filters
        type_value = get_type_from_filters(plan.filters)
        {:ok, edges} = GraphOS.Store.Adapter.ETS.get_edges_by_type(store_ref, type_value)
        edges
        
      # If we're using source + type indices
      :edge_source_type in plan.use_indices && entity_type == :edge ->
        # Extract source and type values from filters
        source_value = get_source_from_filters(plan.filters)
        type_value = get_type_from_filters(plan.filters)
        {:ok, edges} = GraphOS.Store.Adapter.ETS.get_outgoing_edges_by_type(store_ref, source_value, type_value)
        edges
        
      # If we're using target + type indices
      :edge_target_type in plan.use_indices && entity_type == :edge ->
        # Extract target and type values from filters
        target_value = get_target_from_filters(plan.filters)
        type_value = get_type_from_filters(plan.filters)
        {:ok, edges} = GraphOS.Store.Adapter.ETS.get_incoming_edges_by_type(store_ref, target_value, type_value)
        edges
        
      # Default to full table scan with match pattern
      true ->
        table_name = get_table_name(store_ref, entity_type)
        :ets.match_object(table_name, pattern)
    end
    
    {:ok, results}
  end
  
  # Generate possible execution plans and estimate their costs
  defp generate_plans(initial_plan, _opts) do
    # Start with the basic full scan plan
    full_scan_plan = %{
      initial_plan | 
      pattern: compile_match_pattern(initial_plan.filters),
      estimated_cost: estimate_full_scan_cost(initial_plan),
      use_indices: []
    }
    
    # Check if we can use edge type index
    type_plan = if has_type_filter?(initial_plan.filters) do
      %{
        initial_plan |
        pattern: nil,  # No need for pattern, we'll use direct index lookup
        estimated_cost: estimate_type_index_cost(initial_plan),
        use_indices: [:edge_type]
      }
    end
    
    # Check if we can use combined source+type indices
    source_type_plan = if has_source_and_type_filters?(initial_plan.filters) do
      %{
        initial_plan |
        pattern: nil,
        estimated_cost: estimate_source_type_index_cost(initial_plan),
        use_indices: [:edge_source_type]
      }
    end
    
    # Check if we can use combined target+type indices
    target_type_plan = if has_target_and_type_filters?(initial_plan.filters) do
      %{
        initial_plan |
        pattern: nil,
        estimated_cost: estimate_target_type_index_cost(initial_plan),
        use_indices: [:edge_target_type]
      }
    end
    
    # Collect all valid plans
    [full_scan_plan, type_plan, source_type_plan, target_type_plan]
    |> Enum.filter(&(&1 != nil))
  end
  
  # Compile a match pattern for efficient reuse
  defp compile_match_pattern(filters) do
    pattern = build_match_pattern(filters)
    # In a real implementation, we might use :ets.match_spec_compile here
    # For now, we'll just return the pattern directly
    pattern
  end
  
  # Build a match pattern based on filters
  defp build_match_pattern(_filters) do
    # This is a simplified implementation
    # A real implementation would convert filters to proper ETS match specs
    {:_, :_}  # Match any record for now
  end
  
  # Check if filters include a type condition
  defp has_type_filter?(filters) do
    Enum.any?(filters, fn filter ->
      filter.field == "type" && filter.operator == :eq
    end)
  end
  
  # Check if filters include both source and type conditions
  defp has_source_and_type_filters?(filters) do
    has_source = Enum.any?(filters, fn filter -> filter.field == "source" && filter.operator == :eq end)
    has_type = Enum.any?(filters, fn filter -> filter.field == "type" && filter.operator == :eq end)
    has_source && has_type
  end
  
  # Check if filters include both target and type conditions
  defp has_target_and_type_filters?(filters) do
    has_target = Enum.any?(filters, fn filter -> filter.field == "target" && filter.operator == :eq end)
    has_type = Enum.any?(filters, fn filter -> filter.field == "type" && filter.operator == :eq end)
    has_target && has_type
  end
  
  # Extract type value from filters
  defp get_type_from_filters(filters) do
    filter = Enum.find(filters, fn filter -> filter.field == "type" && filter.operator == :eq end)
    filter && filter.value
  end
  
  # Extract source value from filters
  defp get_source_from_filters(filters) do
    filter = Enum.find(filters, fn filter -> filter.field == "source" && filter.operator == :eq end)
    filter && filter.value
  end
  
  # Extract target value from filters
  defp get_target_from_filters(filters) do
    filter = Enum.find(filters, fn filter -> filter.field == "target" && filter.operator == :eq end)
    filter && filter.value
  end
  
  # Get the appropriate table name for the entity type
  defp get_table_name(store_ref, entity_type) do
    # Implementation depends on how table names are generated in the adapter
    # This is a simplified example
    suffix = case entity_type do
      :node -> "_nodes"
      :edge -> "_edges"
      :graph -> "_graphs"
      _ -> raise "Unknown entity type: #{inspect(entity_type)}"
    end
    
    String.to_atom("#{store_ref}#{suffix}")
  end
  
  # Estimate the cost of a full table scan
  defp estimate_full_scan_cost(_plan) do
    # In a real implementation, this would consider table size
    1000.0  # Arbitrary high cost
  end
  
  # Estimate the cost of using the type index
  defp estimate_type_index_cost(_plan) do
    # In a real implementation, this would consider cardinality
    100.0  # Moderate cost
  end
  
  # Estimate the cost of using source+type indices
  defp estimate_source_type_index_cost(_plan) do
    # In a real implementation, this would consider cardinality
    10.0  # Low cost
  end
  
  # Estimate the cost of using target+type indices
  defp estimate_target_type_index_cost(_plan) do
    # In a real implementation, this would consider cardinality
    10.0  # Low cost
  end
end
