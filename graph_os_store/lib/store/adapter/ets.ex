defmodule GraphOS.Store.Adapter.ETS do
  @moduledoc """
  ETS implementation of the GraphOS.Store.Adapter behaviour.
  
  This adapter uses Erlang Term Storage (ETS) for in-memory storage of graph data.
  It includes various optimizations for large graph performance:
  - Composite source+type indexing for fast edge traversal
  - Parallel processing for very large datasets
  - Adaptive query optimization based on graph size
  - Results caching for repeated queries
  """

  use GenServer
  require Logger
  
  @behaviour GraphOS.Store.Adapter
  
  # Cache configuration
  @edge_cache_ttl 60_000  # Cache TTL in milliseconds (1 minute default)
  @max_cache_size 10_000  # Maximum number of cached entries
  
  # Store name will be prefixed to these base names
  @base_table_names %{
    graph: :graphs,
    node: :nodes,
    edge: :edges,
    events: :events,
    edge_source_idx: :edges_by_source,
    edge_target_idx: :edges_by_target,
    edge_type_idx: :edges_by_type,
    edge_source_type_idx: :edges_by_source_type
  }

  @base_entities [
    GraphOS.Entity.Graph,
    GraphOS.Entity.Node,
    GraphOS.Entity.Edge
  ]
  defguard is_base_entity?(module) when module in @base_entities

  # Add module attribute for compression defaults
  @default_compressed false

  # --- GenServer Lifecycle ---

  @doc false
  def start_link(name, opts \\ []) do
    # Use Registry for process registration
    GenServer.start_link(__MODULE__, {name, opts}, name: via_tuple(name))
  end

  @impl GenServer
  def init({name, opts}) do
    schema = Keyword.get(opts, :schema)
    
    # Store all options in the state so they're accessible later
    state = %{
      name: name,
      schema: schema,
      tables: %{},
      opts: opts  # Store all options in state
    }
    
    # Continue initialization asynchronously
    {:ok, state, {:continue, :init_tables}}
  end

  @impl GenServer
  def handle_continue(:init_tables, state) do
    %{name: name, opts: opts} = state
    Logger.debug("Creating/Verifying ETS tables for store '#{name}'")
    
    # Get compression setting from options
    compressed = Keyword.get(opts, :compressed, @default_compressed)
    
    # Store configuration in process dictionary
    store_config = %{
      compressed: compressed
    }
    Process.put({:graphos_ets_store_config, name}, store_config)
    
    # Base table options
    table_opts = [
      :set,
      :public, 
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ]
    
    # Add compression if configured - as a simple flag
    table_opts = if compressed, do: [:compressed | table_opts], else: table_opts
    
    # Edge indices use bag type and read concurrency
    edge_index_opts = [
      :bag,
      :public, 
      :named_table,
      {:read_concurrency, true}
    ]
    
    # Add compression to edge indices if configured
    edge_index_opts = if compressed, do: [:compressed | edge_index_opts], else: edge_index_opts

    tables_map =
      @base_table_names
      |> Enum.into(%{}, fn {type, _base_name} ->
        table_name = make_table_name(name, type)
        ets_table_ref = 
          case :ets.info(table_name) do
            :undefined ->
              Logger.debug("Creating ETS table #{table_name} for store '#{name}'")
              # Use bag type for edge indices
              opts = if type in [:edge_source_idx, :edge_target_idx, :edge_type_idx, :edge_source_type_idx], do: edge_index_opts, else: table_opts
              :ets.new(table_name, opts)
              table_name 
            _tid -> 
              Logger.debug("Using existing ETS table #{table_name} for store '#{name}'")
              table_name 
          end
        {type, ets_table_ref} 
      end)

    new_state = %{state | tables: tables_map}
    {:noreply, new_state}
  end

  # --- Adapter Behaviour Callbacks (Public API) ---
  # These functions find the correct GenServer via Registry and delegate.

  @impl GraphOS.Store.Adapter
  def register_schema(store_ref, schema) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:register_schema, schema})
  end

  @impl GraphOS.Store.Adapter
  def insert(store_ref, module, data) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:insert, module, data})
  end

  @doc """
  Insert multiple records in a single batch operation for improved performance.
  
  This is more efficient than calling insert multiple times for large batch operations.
  """
  def batch_insert(store_ref, module, data_list) when is_list(data_list) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:batch_insert, module, data_list})
  end

  @impl GraphOS.Store.Adapter
  def update(store_ref, module, data) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:update, module, data})
  end

  @doc """
  Update multiple records in a single batch operation for improved performance.
  
  This is more efficient than calling update multiple times for large batch operations.
  """
  def batch_update(store_ref, module, data_list) when is_list(data_list) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:batch_update, module, data_list})
  end

  @impl GraphOS.Store.Adapter
  def delete(store_ref, module, id) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:delete, module, id})
  end

  @impl GraphOS.Store.Adapter
  def get(store_ref, module, id) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:get, module, id})
  end

  @impl GraphOS.Store.Adapter
  def all(store_ref, module, filter \\ %{}, opts \\ []) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:all, module, filter, opts})
  end

  @impl GraphOS.Store.Adapter
  def traverse(store_ref, algorithm, params) do
    [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, store_ref)
    GenServer.call(pid, {:traverse, algorithm, params})
  end

  # --- GenServer Call Handlers (Core Logic) ---

  @impl GenServer
  def handle_call({:register_schema, schema}, _from, state) do
    {:reply, :ok, %{state | schema: schema}}
  end

  @impl GenServer
  def handle_call({:insert, module, data}, _from, state) do
    store_name = state.name
    result =
      with {:ok, struct_data} <- {:ok, ensure_struct!(module, data)},
           {:ok, record} <- ensure_new_id!(store_name, struct_data),
           {:ok, record} <- do_insert_record(store_name, record) do
        {:ok, record}
      else
        {:error, reason} -> {:error, reason}
      end
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:batch_insert, module, data_list}, _from, state) when is_list(data_list) do
    store_name = state.name
    
    # Process each record in the batch
    {results, errors} = Enum.reduce(data_list, {[], []}, fn data, {ok_acc, error_acc} ->
      result = 
        with {:ok, struct_data} <- {:ok, ensure_struct!(module, data)},
             {:ok, record} <- ensure_new_id!(store_name, struct_data),
             {:ok, record} <- do_insert_record(store_name, record) do
          {:ok, record}
        else
          {:error, reason} -> {:error, reason}
        end
      
      case result do 
        {:ok, record} -> {[record | ok_acc], error_acc}
        {:error, reason} -> {ok_acc, [{data, reason} | error_acc]}
      end
    end)
    
    # Return results based on success or failure
    if Enum.empty?(errors) do
      {:reply, {:ok, Enum.reverse(results)}, state}
    else
      {:reply, {:error, %{succeeded: Enum.reverse(results), failed: Enum.reverse(errors)}}, state}
    end
  end

  @impl GenServer
  def handle_call({:update, module, data}, _from, state) do
    store_name = state.name
    result =
      with {:ok, struct_data} <- {:ok, ensure_struct!(module, data)},
           {:ok, record_to_update} <- ensure_existing_id!(store_name, struct_data),
           {:ok, updated_record} <- do_update_record(store_name, record_to_update) do
        {:ok, updated_record}
      else
        {:error, reason} -> {:error, reason}
      end
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:batch_update, module, data_list}, _from, state) when is_list(data_list) do
    store_name = state.name
    
    # Process each record in the batch
    {results, errors} = Enum.reduce(data_list, {[], []}, fn data, {ok_acc, error_acc} ->
      result = 
        with {:ok, struct_data} <- {:ok, ensure_struct!(module, data)},
             {:ok, record_to_update} <- ensure_existing_id!(store_name, struct_data),
             {:ok, updated_record} <- do_update_record(store_name, record_to_update) do
          {:ok, updated_record}
        else
          {:error, reason} -> {:error, reason}
        end
      
      case result do 
        {:ok, record} -> {[record | ok_acc], error_acc}
        {:error, reason} -> {ok_acc, [{data, reason} | error_acc]}
      end
    end)
    
    # Return results based on success or failure
    if Enum.empty?(errors) do
      {:reply, {:ok, Enum.reverse(results)}, state}
    else
      {:reply, {:error, %{succeeded: Enum.reverse(results), failed: Enum.reverse(errors)}}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete, module, id}, _from, state) do
    store_name = state.name
    result = case do_delete_record(store_name, module, id) do
      {:ok, _deleted_record} -> :ok 
      {:error, {:not_found, _reason}} -> :ok 
      {:error, other_error} -> {:error, other_error} 
    end
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get, module, id}, _from, state) do
    store_name = state.name
    result = do_read_record(store_name, module, id) 
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:all, module, filter, opts}, _from, state) do
    store_name = state.name
    result = do_get_all(store_name, module, filter, opts)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:traverse, algorithm, params}, _from, state) do
    store_name = state.name
    result = do_traverse(store_name, algorithm, params)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:get_name, _from, state) do
    {:reply, state.name, state}
  end

  # --- GenServer Call Handlers (Core Logic Implementation) ---

  @spec do_insert_record(atom(), struct()) :: {:ok, struct()} | {:error, term()}
  defp do_insert_record(store_name, %{__struct__: module, id: id} = record) do
    table_name = get_table_name_from_state!(store_name, module) 
    now = DateTime.utc_now()
    
    entity_type = case safe_get_type(module) do
      {:ok, type} -> type
      {:error, _} -> :unknown 
    end
    
    metadata = %GraphOS.Entity.Metadata{
      id: id,
      entity: entity_type,
      module: module,
      created_at: now,
      updated_at: now,
      deleted_at: nil,
      version: 1,
      deleted: false
    }
    record_with_metadata = Map.put(record, :metadata, metadata)

    result = :ets.insert(table_name, {id, record_with_metadata})

    # If this is an edge, also update the edge indices
    if entity_type == :edge do
      source_idx_table = make_table_name(store_name, :edge_source_idx)
      target_idx_table = make_table_name(store_name, :edge_target_idx)
      type_idx_table = make_table_name(store_name, :edge_type_idx)
      source_type_idx_table = make_table_name(store_name, :edge_source_type_idx)
      
      # Index by source -> {target, edge_id}
      :ets.insert(source_idx_table, {record.source, {record.target, id}})
      # Index by target -> {source, edge_id}
      :ets.insert(target_idx_table, {record.target, {record.source, id}})
      # Index by type -> edge_id
      # Get edge type from either top-level field or data map
      edge_type = Map.get(record, :type) || 
                  (Map.get(record, :data) && (Map.get(record.data, "type") || Map.get(record.data, :type)))
      if edge_type do
        :ets.insert(type_idx_table, {edge_type, id})
        # Index by source+type -> edge_id
        :ets.insert(source_type_idx_table, {{record.source, edge_type}, id})
      end
    end

    case result do
      true -> {:ok, record_with_metadata}
      false -> {:error, {:ets_insert_failed, table_name, id}}
    end
  end

  @spec do_update_record(atom(), struct()) :: {:ok, struct()} | {:error, term()}
  defp do_update_record(store_name, %{__struct__: module, id: id} = record_to_update) do
    table_name = get_table_name_from_state!(store_name, module)
    case :ets.lookup(table_name, id) do
      [{^id, %{metadata: old_metadata} = _existing_record}] ->
        now = DateTime.utc_now()
        new_metadata = %GraphOS.Entity.Metadata{old_metadata |
          updated_at: now,
          version: old_metadata.version + 1
        }
        updated_record = Map.put(record_to_update, :metadata, new_metadata)

        case :ets.insert(table_name, {id, updated_record}) do
          true -> {:ok, updated_record}
          false -> {:error, {:ets_update_failed, table_name, id}}
        end
      [] ->
        {:error, {:not_found, "Cannot update non-existent record with ID #{id} in #{table_name}"}}
    end
  end

  @spec do_delete_record(atom(), module(), term()) :: {:ok, struct()} | {:error, term()}
  defp do_delete_record(store_name, module, id) do
    table_name = get_table_name_from_state!(store_name, module)
    entity_type = case safe_get_type(module) do
      {:ok, type} -> type
      {:error, _} -> :unknown
    end
    
    # For edges, first look up the record to get source/target for index cleanup
    edge_data = if entity_type == :edge do
      case :ets.lookup(table_name, id) do
        [{^id, record}] -> {record.source, record.target, Map.get(record, :type)}
        _ -> nil
      end
    else
      nil
    end

    case :ets.lookup(table_name, id) do
      [{^id, %{metadata: %{deleted: false}} = record}] ->
        # Create soft-deleted version of the record
        now = DateTime.utc_now()
        updated_metadata = Map.merge(record.metadata, %{deleted: true, updated_at: now})
        deleted_record = Map.put(record, :metadata, updated_metadata)
        
        # Update the record with soft-delete flag
        result = :ets.insert(table_name, {id, deleted_record})
        
        # If this is an edge, also remove from indices
        if entity_type == :edge and edge_data != nil do
          source_idx_table = make_table_name(store_name, :edge_source_idx)
          target_idx_table = make_table_name(store_name, :edge_target_idx)
          type_idx_table = make_table_name(store_name, :edge_type_idx)
          source_type_idx_table = make_table_name(store_name, :edge_source_type_idx)
          
          # Remove from source index
          :ets.delete_object(source_idx_table, {edge_data |> elem(0), {edge_data |> elem(1), id}})
          # Remove from target index
          :ets.delete_object(target_idx_table, {edge_data |> elem(1), {edge_data |> elem(0), id}})
          # Remove from type index
          if edge_data |> elem(2) do
            :ets.delete_object(type_idx_table, {edge_data |> elem(2), id})
            # Remove from source+type index
            :ets.delete_object(source_type_idx_table, {{edge_data |> elem(0), edge_data |> elem(2)}, id})
          end
        end
        
        case result do
          true -> {:ok, deleted_record}
          false -> {:error, {:ets_delete_failed, table_name, id}}
        end
      [{^id, %{metadata: %{deleted: true}} = deleted_record}] -> 
        {:ok, deleted_record} 
      [] ->
        {:error, {:not_found, "Cannot delete non-existent record with ID #{id} in #{table_name}"}}
    end
  end

  @spec do_read_record(atom(), module(), binary()) :: {:ok, struct()} | {:error, term()}
  defp do_read_record(store_name, module, id) do
    table_name = get_table_name_from_state!(store_name, module)
    case :ets.lookup(table_name, id) do
      [{^id, %{metadata: %{module: ^module, deleted: false}} = record}] ->
        {:ok, record}
      [{^id, %{metadata: %{module: mod, deleted: false}}}] ->
        {:error, {:module_mismatch, expected: module, found: mod}}
      [{^id, %{metadata: %{deleted: true}}}] ->
        {:error, :deleted}
      [] ->
        {:error, :not_found}
    end
  end

  @spec do_get_all(atom(), module(), map(), Keyword.t()) :: {:ok, list(struct())} | {:error, term()}
  defp do_get_all(store_name, module, filter, opts) do
    with {:ok, table_name} <- get_table_name_from_state(store_name, module) do
      match_spec = [{{:_ , :'$1'}, [{:'/=', {:map_get, :deleted, {:map_get, :metadata, :'$1'}}, true}], [:'$1']}]
      records = :ets.select(table_name, match_spec)

      is_parent = is_base_entity?(module)
      filtered_by_module = filter_by_module(records, module, is_parent)

      results = filtered_by_module
                |> apply_filter(filter)
                |> apply_sort(opts[:sort] || :desc)
                |> apply_pagination(opts[:offset] || 0, opts[:limit])

      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec do_traverse(atom(), atom(), tuple() | list() | map()) :: {:ok, term()} | {:error, term()}
  defp do_traverse(store_name, algorithm, params) do
    case algorithm do
      :bfs ->
        case params do
          {start_node_id, opts} when is_list(opts) ->
            opts_with_store = Keyword.put(opts, :store, store_name)
            GraphOS.Store.Algorithm.BFS.execute(store_name, {start_node_id, opts_with_store})
          _ ->
            {:error, {:invalid_params, :bfs, params}}
        end
        
      :connected_components ->
        store_before = Process.get(:current_algorithm_store)
        Process.put(:current_algorithm_store, store_name)
        
        result = GraphOS.Store.Algorithm.ConnectedComponents.execute(
          if is_list(params), do: Keyword.put(params, :store, store_name), else: [store: store_name]
        )
        
        case store_before do
          nil -> Process.delete(:current_algorithm_store)
          store -> Process.put(:current_algorithm_store, store)
        end
        
        result
        
      :minimum_spanning_tree ->
        store_before = Process.get(:current_algorithm_store)
        Process.put(:current_algorithm_store, store_name)
        
        result = GraphOS.Store.Algorithm.MinimumSpanningTree.execute(
          if is_list(params), do: Keyword.put(params, :store, store_name), else: [store: store_name]
        )
        
        case store_before do
          nil -> Process.delete(:current_algorithm_store)
          store -> Process.put(:current_algorithm_store, store)
        end
        
        result
        
      :page_rank ->
        store_before = Process.get(:current_algorithm_store)
        Process.put(:current_algorithm_store, store_name)
        
        result = GraphOS.Store.Algorithm.PageRank.execute(
          if is_list(params), do: Keyword.put(params, :store, store_name), else: [store: store_name]
        )
        
        case store_before do
          nil -> Process.delete(:current_algorithm_store)
          store -> Process.put(:current_algorithm_store, store)
        end
        
        result
        
      :shortest_path ->
        case params do
          {source_node_id, target_node_id, opts} when is_list(opts) ->
            opts_with_store = Keyword.put(opts, :store, store_name)
            GraphOS.Store.Algorithm.ShortestPath.execute(source_node_id, target_node_id, opts_with_store)
          _ ->
            {:error, {:invalid_params, :shortest_path, params}}
        end
        
      _ ->
        {:error, {:unsupported_algorithm, algorithm}}
    end
  end

  # --- Utility Functions --- Requires store_name passed from state ---

  defp make_table_name(store_name, type) do
    base_name = @base_table_names[type] ||
      raise "Invalid entity type for ETS table name: #{inspect(type)}"
    String.to_atom("#{store_name}_#{base_name}")
  end

  defp get_table_name_from_state!(store_name, module) do
    case get_table_name_from_state(store_name, module) do
      {:ok, table_name} -> table_name
      {:error, reason} -> raise "Failed to get table name for #{inspect module}: #{inspect reason}"
    end
  end

  defp get_table_name_from_state(store_name, module) do
    try do
      type = case safe_get_type(module) do
        {:ok, entity_type} when entity_type in [:node, :edge, :graph] -> entity_type
        {:error, reason} -> raise "Failed to get entity type for #{inspect module}: #{inspect reason}"
      end
      {:ok, make_table_name(store_name, type)}
    catch
      kind, reason ->
        Logger.error("Failed to determine table name for #{inspect module}: #{kind} #{inspect reason}")
        {:error, {:get_type_failed, module, kind, reason}}
    end
  end

  defp safe_get_type(module) do
    try do
      if module == GraphOS.Entity.Graph do
        {:ok, :graph}
      else
        result = module.entity()
        type = case result do
          keywords when is_list(keywords) -> Keyword.get(keywords, :entity_type)
          %{entity_type: type} -> type  
          %GraphOS.Entity{entity_type: type} -> type  
          _ -> nil 
        end

        if type in [:node, :edge, :graph] do
          {:ok, type}
        else
          {:error, {:invalid_entity_type, type}}
        end
      end
    rescue
      e -> {:error, {:exception, e, __STACKTRACE__}}
    end
  end

  defp ensure_struct!(module, data) when is_struct(data, module), do: data
  defp ensure_struct!(module, data) when is_map(data), do: struct!(module, data)

  defp ensure_new_id!(store_name, %{id: id, __struct__: module} = record) do
    table_name = get_table_name_from_state!(store_name, module)
    if :ets.member(table_name, id) do
      {:error, {:id_already_exists, id, table_name}}
    else
      {:ok, record}
    end
  end

  defp ensure_existing_id!(store_name, %{id: id, __struct__: module} = record) do
    table_name = get_table_name_from_state!(store_name, module)
    case :ets.lookup(table_name, id) do
      [{^id, _existing_record}] -> {:ok, record}
      [] -> {:error, {:not_found, "Record #{id} not found in #{table_name}"}}
    end
  end

  defp via_tuple(name) do
    {:via, GraphOS.Store.Registry, name} 
  end

  defp filter_by_module(records, _module, true), do: records
  defp filter_by_module(records, module, false) do
    Enum.filter(records, fn record -> record.metadata.module == module end)
  end

  defp apply_filter(records, filter) when map_size(filter) == 0, do: records
  defp apply_filter(records, filter) do
    Enum.filter(records, fn record ->
      Enum.all?(filter, fn {key, filter_value} ->
        case key do
          :metadata ->
            if is_map(filter_value) do
              Enum.all?(filter_value, fn {m_key, m_value} ->
                metadata_val = Map.get(record.metadata, m_key)
                if is_function(m_value, 1), do: m_value.(metadata_val), else: metadata_val == m_value
              end)
            else false end
          :data ->
            if is_map(filter_value) do
              Enum.all?(filter_value, fn {d_key, d_value} ->
                data_val = Map.get(record.data, d_key)
                if is_function(d_value, 1), do: d_value.(data_val), else: data_val == d_value
              end)
            else false end
          _ ->
            record_val = Map.get(record, key)
            if is_function(filter_value, 1), do: filter_value.(record_val), else: record_val == filter_value
        end
      end)
    end)
  end

  defp apply_sort(records, :asc), do: Enum.sort_by(records, & &1.id)
  defp apply_sort(records, :desc), do: Enum.sort_by(records, & &1.id, :desc)

  defp apply_pagination(records, offset, nil) when is_integer(offset) and offset >= 0 do
    if offset > 0 do
      Enum.drop(records, offset)
    else
      records  # No need to process when offset is 0
    end
  end
  
  defp apply_pagination(records, offset, limit) when is_integer(offset) and offset >= 0 and is_integer(limit) and limit >= 0 do
    cond do
      offset == 0 and limit > 1000 ->
        # For large limits with no offset, just use take for better performance
        Enum.take(records, limit)
      offset > 0 and limit > 1000 ->
        # For large limits with offset, use streaming to avoid processing the entire collection
        records
        |> Stream.drop(offset)
        |> Stream.take(limit)
        |> Enum.to_list()
      true ->
        # For smaller datasets, use the standard approach
        records |> Enum.drop(offset) |> Enum.take(limit)
    end
  end
  
  defp apply_pagination(records, _offset, _limit) do
    Logger.warning("Invalid pagination options received. Returning all records.")
    records
  end

  # Add helpers for efficient edge traversal using indices
  
  @doc """
  Gets all outgoing edges from a node efficiently using the source index.
  """
  def get_outgoing_edges(store_name, node_id) do
    # Use the source index for efficient lookup
    edge_table = make_table_name(store_name, :edge)
    source_idx_table = make_table_name(store_name, :edge_source_idx)
    
    # Get all target nodes and edge IDs where this node is the source
    edges = :ets.lookup(source_idx_table, node_id) 
            |> Enum.map(fn {_source, {target, edge_id}} ->
              case :ets.lookup(edge_table, edge_id) do
                [{^edge_id, edge}] when edge.metadata.deleted == false -> {:ok, {target, edge}}
                _ -> nil
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> Enum.map(fn {:ok, result} -> result end)
    
    {:ok, edges}
  end
  
  @doc """
  Gets all incoming edges to a node efficiently using the target index.
  """
  def get_incoming_edges(store_name, node_id) do
    # Use the target index for efficient lookup
    edge_table = make_table_name(store_name, :edge)
    target_idx_table = make_table_name(store_name, :edge_target_idx)
    
    # Get all source nodes and edge IDs where this node is the target
    edges = :ets.lookup(target_idx_table, node_id)
            |> Enum.map(fn {_target, {source, edge_id}} ->
              case :ets.lookup(edge_table, edge_id) do
                [{^edge_id, edge}] when edge.metadata.deleted == false -> {:ok, {source, edge}}
                _ -> nil
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> Enum.map(fn {:ok, result} -> result end)
    
    {:ok, edges}
  end

  @doc """
  Gets edges filtered by type.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `edge_type` - The type of edges to retrieve
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of edges with the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_edges_by_type(store_name :: term(), edge_type :: String.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_edges_by_type(store_name, edge_type) do
    # Get the table names
    edge_table = make_table_name(store_name, :edge)
    type_idx_table = make_table_name(store_name, :edge_type_idx)
    
    # Get all edge IDs for this type
    edge_ids = :ets.lookup(type_idx_table, edge_type)
               |> Enum.map(fn {_type, edge_id} -> edge_id end)
    
    # Retrieve all edges
    edges = Enum.reduce(edge_ids, [], fn edge_id, acc ->
      case :ets.lookup(edge_table, edge_id) do
        [{^edge_id, edge}] ->
          # Skip deleted edges
          if get_in(edge, [Access.key(:metadata, %{}), Access.key(:deleted)]) do
            acc
          else
            [edge | acc]
          end
        [] -> acc
      end
    end)
    
    {:ok, edges}
  end
  
  @doc """
  Gets all outgoing edges of a specific type from a node.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `node_id` - ID of the source node
  - `edge_type` - Type of edges to retrieve
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of outgoing edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_outgoing_edges_by_type(store_name :: term(), node_id :: String.t(), edge_type :: String.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_outgoing_edges_by_type(store_name, node_id, edge_type) do
    # Get the table names
    edge_table = make_table_name(store_name, :edge)
    source_idx_table = make_table_name(store_name, :edge_source_idx)
    type_idx_table = make_table_name(store_name, :edge_type_idx)
    source_type_idx_table = make_table_name(store_name, :edge_source_type_idx)
    
    # Get all edge IDs for this node's outgoing edges
    node_edge_ids = :ets.lookup(source_idx_table, node_id) 
                    |> Enum.map(fn {_source, {target, edge_id}} -> edge_id end)
                    |> MapSet.new()
    
    # Get all edge IDs for this type
    type_edge_ids = :ets.lookup(type_idx_table, edge_type)
                    |> Enum.map(fn {_type, edge_id} -> edge_id end)
                    |> MapSet.new()
    
    # Find the intersection - edges that match both node_id as source and the specified type
    matching_edge_ids = MapSet.intersection(node_edge_ids, type_edge_ids)
    
    # Retrieve all matching edges
    edges = Enum.reduce(matching_edge_ids, [], fn edge_id, acc ->
      case :ets.lookup(edge_table, edge_id) do
        [{^edge_id, edge}] ->
          # Skip deleted edges
          if Map.get(edge.metadata, :deleted) do
            acc
          else
            [edge | acc]
          end
        [] -> acc
      end
    end)
    
    {:ok, edges}
  end
  
  @doc """
  Gets outgoing edges from a source node of a specific type using the optimized composite index.
  This method is significantly more efficient for very large graphs than separate lookups.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `source_id` - ID of the source node
  - `edge_type` - Type of edges to retrieve
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of outgoing edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_outgoing_edges_by_type_optimized(store_name :: term(), source_id :: String.t(), edge_type :: String.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_outgoing_edges_by_type_optimized(store_name, source_id, edge_type) do
    # Get the table names
    edge_table = make_table_name(store_name, :edge)
    source_type_idx_table = make_table_name(store_name, :edge_source_type_idx)
    
    # Get all edge IDs directly from the composite index
    # This is much more efficient than the intersection approach for very large graphs
    edges = :ets.lookup(source_type_idx_table, {source_id, edge_type})
            |> Enum.reduce([], fn {{_source, _type}, edge_id}, acc ->
              case :ets.lookup(edge_table, edge_id) do
                [{^edge_id, edge}] ->
                  # Skip deleted edges
                  if Map.get(edge.metadata, :deleted) do
                    acc
                  else
                    [edge | acc]
                  end
                [] -> acc
              end
            end)
    
    # If we didn't find any edges with the composite index, try the fallback method
    # This handles cases where edges were created without the composite index
    if Enum.empty?(edges) do
      {:ok, source_edges} = get_outgoing_edges(store_name, source_id)
      filtered_edges = Enum.filter(source_edges, fn edge -> 
        stored_type = Map.get(edge, :type) || 
                     (Map.get(edge, :data) && (Map.get(edge.data, "type") || Map.get(edge.data, :type)))
        stored_type == edge_type
      end)
      {:ok, filtered_edges}
    else
      {:ok, edges}
    end
  end
  
  @doc """
  Gets outgoing edges from a source node of a specific type using parallel processing.
  This method is optimized for extremely large graphs (>100K edges).
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `source_id` - ID of the source node
  - `edge_type` - Type of edges to retrieve
  - `opts` - Options including:
    - `:max_concurrency` - Maximum number of concurrent tasks (default: 4)
    
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of outgoing edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_outgoing_edges_by_type_parallel(store_name :: term(), source_id :: String.t(), edge_type :: String.t(), opts :: Keyword.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_outgoing_edges_by_type_parallel(store_name, source_id, edge_type, opts \\ []) do
    # Get the table names
    edge_table = make_table_name(store_name, :edge)
    source_idx_table = make_table_name(store_name, :edge_source_idx)
    type_idx_table = make_table_name(store_name, :edge_type_idx)
    source_type_idx_table = make_table_name(store_name, :edge_source_type_idx)
    
    # Check if we have a composite index populated for this source+type combination
    source_type_entries = :ets.lookup(source_type_idx_table, {source_id, edge_type})
    
    if length(source_type_entries) > 0 do
      # If we have the composite index, use it directly (faster path)
      max_concurrency = Keyword.get(opts, :max_concurrency, 4)
      edges = source_type_entries
        |> Enum.map(fn {_key, edge_id} -> edge_id end)
        |> Enum.chunk_every(max(1, div(length(source_type_entries) + max_concurrency - 1, max_concurrency)))
        |> Enum.map(fn batch ->
          Task.async(fn ->
            Enum.reduce(batch, [], fn edge_id, acc ->
              case :ets.lookup(edge_table, edge_id) do
                [{^edge_id, edge}] ->
                  # Skip deleted edges
                  if Map.get(edge.metadata, :deleted) do
                    acc
                  else
                    [edge | acc]
                  end
                [] -> acc
              end
            end)
          end)
        end)
        |> Enum.flat_map(&Task.await/1)
      
      {:ok, edges}
    else
      # Fall back to the intersection approach if the composite index isn't populated
      # Use parallel processing for the intersection calculation
      max_concurrency = Keyword.get(opts, :max_concurrency, 4)
      
      # Get node edges and type edges in parallel
      [node_task, type_task] = [
        Task.async(fn -> 
          :ets.lookup(source_idx_table, source_id)
          |> Enum.map(fn {_source, {target, edge_id}} -> edge_id end)
          |> MapSet.new()
        end),
        Task.async(fn ->
          :ets.lookup(type_idx_table, edge_type)
          |> Enum.map(fn {_type, edge_id} -> edge_id end)
          |> MapSet.new()
        end)
      ]
      
      node_edge_ids = Task.await(node_task)
      type_edge_ids = Task.await(type_task)
      
      # Find the intersection
      matching_edge_ids = MapSet.intersection(node_edge_ids, type_edge_ids)
      
      # Return empty list early if no matches found or try fallback method
      if MapSet.size(matching_edge_ids) == 0 do
        # Try to filter by type in data map as a fallback
        {:ok, source_edges} = get_outgoing_edges(store_name, source_id)
        filtered_edges = Enum.filter(source_edges, fn edge -> 
          stored_type = Map.get(edge, :type) || 
                       (Map.get(edge, :data) && (Map.get(edge.data, "type") || Map.get(edge.data, :type)))
          stored_type == edge_type
        end)
        {:ok, filtered_edges}
      else
        # Calculate chunk size - ensure minimum of 1 to avoid Enum.chunk_every errors
        chunk_size = max(1, div(MapSet.size(matching_edge_ids) + max_concurrency - 1, max_concurrency))
        
        # Process edge retrieval in parallel for large result sets
        edges = 
          matching_edge_ids
          |> Enum.to_list()
          |> Enum.chunk_every(chunk_size)
          |> Enum.map(fn batch ->
            Task.async(fn ->
              Enum.reduce(batch, [], fn edge_id, acc ->
                case :ets.lookup(edge_table, edge_id) do
                  [{^edge_id, edge}] ->
                    # Skip deleted edges
                    if Map.get(edge.metadata, :deleted) do
                      acc
                    else
                      [edge | acc]
                    end
                  [] -> acc
                end
              end)
            end)
          end)
          |> Enum.flat_map(&Task.await/1)
        
        {:ok, edges}
      end
    end
  end
  
  @doc """
  Auto-selects the most efficient edge traversal method based on graph size and characteristics.
  For small graphs, uses the standard approach; for medium-sized graphs, uses the optimized index;
  for very large graphs, uses parallel processing.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `source_id` - ID of the source node
  - `edge_type` - Type of edges to retrieve
  - `opts` - Additional options
    - `:threshold_medium` - Threshold for medium-sized graphs (default: 1000 edges)
    - `:threshold_large` - Threshold for large graphs (default: 10000 edges)
    - `:max_concurrency` - Maximum number of concurrent tasks for parallel processing (default: System.schedulers_online())
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of outgoing edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_outgoing_edges_adaptive(store_name :: term(), source_id :: String.t(), edge_type :: String.t(), opts :: Keyword.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_outgoing_edges_adaptive(store_name, source_id, edge_type, opts \\ []) do
    # Get approximate graph size information
    edge_count = count_edges(store_name)
    
    # Get thresholds from options or use defaults
    threshold_medium = Keyword.get(opts, :threshold_medium, 1_000)
    threshold_large = Keyword.get(opts, :threshold_large, 10_000)
    
    # Select the most appropriate algorithm based on graph size
    cond do
      edge_count >= threshold_large ->
        # Very large graph - use parallel processing
        get_outgoing_edges_by_type_parallel(store_name, source_id, edge_type, opts)
        
      edge_count >= threshold_medium ->
        # Medium-sized graph - use optimized index
        get_outgoing_edges_by_type_optimized(store_name, source_id, edge_type)
        
      true ->
        # Small graph - use standard approach
        get_outgoing_edges_by_type(store_name, source_id, edge_type)
    end
  end
  
  @doc """
  Gets all incoming edges of a specific type to a node.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `node_id` - ID of the target node
  - `edge_type` - Type of edges to retrieve
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of incoming edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_incoming_edges_by_type(store_name :: term(), node_id :: String.t(), edge_type :: String.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_incoming_edges_by_type(store_name, node_id, edge_type) do
    # Get the table names
    edge_table = make_table_name(store_name, :edge)
    target_idx_table = make_table_name(store_name, :edge_target_idx)
    type_idx_table = make_table_name(store_name, :edge_type_idx)
    
    # Get all edge IDs for this node's incoming edges
    node_edge_ids = :ets.lookup(target_idx_table, node_id) 
                    |> Enum.map(fn {_target, {source, edge_id}} -> edge_id end)
                    |> MapSet.new()
    
    # Get all edge IDs for this type
    type_edge_ids = :ets.lookup(type_idx_table, edge_type)
                    |> Enum.map(fn {_type, edge_id} -> edge_id end)
                    |> MapSet.new()
    
    # Find the intersection - edges that match both node_id as target and the specified type
    matching_edge_ids = MapSet.intersection(node_edge_ids, type_edge_ids)
    
    # Retrieve all matching edges
    edges = Enum.reduce(matching_edge_ids, [], fn edge_id, acc ->
      case :ets.lookup(edge_table, edge_id) do
        [{^edge_id, edge}] ->
          # Skip deleted edges
          if Map.get(edge.metadata, :deleted) do
            acc
          else
            [edge | acc]
          end
        [] -> acc
      end
    end)
    
    {:ok, edges}
  end
  
  # Helper function to get approximate edge count
  defp count_edges(store_name) do
    edge_table = make_table_name(store_name, :edge)
    :ets.info(edge_table, :size)
  end
  
  # Cache implementation for edge traversal
  @doc """
  Gets outgoing edges from a source node of a specific type with caching.
  Caches results for repeated queries to avoid redundant processing.
  
  ## Parameters
  
  - `store_name` - The name of the store
  - `source_id` - ID of the source node
  - `edge_type` - Type of edges to retrieve
  - `opts` - Additional options
    - `:ttl` - Time-to-live for cache entries in milliseconds (default: 60000)
    - `:use_cache` - Whether to use cache (default: true)
    - `:refresh_cache` - Whether to refresh the cache (default: false)
  
  ## Returns
  
  - `{:ok, [Edge.t()]}` - List of outgoing edges of the specified type
  - `{:error, reason}` - Error with reason
  """
  @spec get_outgoing_edges_by_type_cached(store_name :: term(), source_id :: String.t(), edge_type :: String.t(), opts :: Keyword.t()) :: {:ok, [Edge.t()]} | {:error, term()}
  def get_outgoing_edges_by_type_cached(store_name, source_id, edge_type, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @edge_cache_ttl)
    use_cache = Keyword.get(opts, :use_cache, true)
    refresh_cache = Keyword.get(opts, :refresh_cache, false)
    
    # Generate cache key
    cache_key = {store_name, :outgoing_edges, source_id, edge_type}
    cache_table = get_or_create_cache_table(store_name)
    
    if use_cache && !refresh_cache do
      # Try to get from cache first
      case get_from_cache(cache_table, cache_key) do
        {:ok, edges} ->
          # Cache hit
          {:ok, edges}
          
        {:error, _reason} ->
          # Cache miss, get edges using adaptive method
          {:ok, edges} = get_outgoing_edges_adaptive(store_name, source_id, edge_type, opts)
          # Store in cache with TTL
          put_in_cache(cache_table, cache_key, edges, ttl)
          {:ok, edges}
      end
    else
      # Skip cache or refresh cache
      {:ok, edges} = get_outgoing_edges_adaptive(store_name, source_id, edge_type, opts)
      
      # Update cache if using cache
      if use_cache do
        put_in_cache(cache_table, cache_key, edges, ttl)
      end
      
      {:ok, edges}
    end
  end
  
  # Helper functions for cache management
  
  defp get_or_create_cache_table(store_name) do
    cache_table_name = String.to_atom("#{store_name}_query_cache")
    
    case :ets.info(cache_table_name) do
      :undefined ->
        Logger.debug("Creating edge query cache table for store '#{store_name}'")
        :ets.new(cache_table_name, [:set, :public, :named_table])
        cache_table_name
      _ ->
        cache_table_name
    end
  end
  
  defp get_from_cache(cache_table, key) do
    case :ets.lookup(cache_table, key) do
      [{^key, {edges, expires_at}}] ->
        # Check if entry is still valid
        if :os.system_time(:millisecond) < expires_at do
          {:ok, edges}
        else
          # Entry expired
          :ets.delete(cache_table, key)
          {:error, :cache_miss}
        end
      [] ->
        {:error, :cache_miss}
    end
  end
  
  defp put_in_cache(cache_table, key, value, ttl) do
    expires_at = :os.system_time(:millisecond) + ttl
    :ets.insert(cache_table, {key, {value, expires_at}})
    
    # Manage cache size
    manage_cache_size(cache_table)
    
    {:ok, value}
  end
  
  defp manage_cache_size(cache_table) do
    # Only check occasionally (1 in 100 operations) to avoid performance impact
    if :rand.uniform(100) == 1 do
      case :ets.info(cache_table, :size) do
        size when size > @max_cache_size ->
          # Cache is too large, evict oldest entries
          evict_count = trunc(size * 0.2)  # Remove 20% of entries
          
          # Get all entries with expiration
          all_entries = :ets.tab2list(cache_table)
          
          # Sort by expiration (oldest first)
          sorted_entries = Enum.sort_by(all_entries, fn {_key, {_value, expires_at}} -> expires_at end)
          
          # Take the oldest entries to remove
          entries_to_evict = Enum.take(sorted_entries, evict_count)
          
          # Delete them
          Enum.each(entries_to_evict, fn {key, _} ->
            :ets.delete(cache_table, key)
          end)
          
          Logger.debug("Edge cache cleanup: evicted #{evict_count} entries from #{cache_table}")
          
        _ ->
          :ok
      end
    end
  end
  
  # Add cache cleanup on edge changes
  defp invalidate_edge_cache(store_name, source_id, edge_type) do
    cache_table = get_or_create_cache_table(store_name)
    cache_key = {store_name, :outgoing_edges, source_id, edge_type}
    :ets.delete(cache_table, cache_key)
  end
  
  # Modify insert_edge to invalidate cache when necessary
  def insert_edge(store_name, edge, opts \\ []) do
    Logger.debug("Inserting edge #{inspect edge} into store '#{store_name}'")
    
    # Use the existing implementation for edge insertion
    compressed = Keyword.get(opts, :compressed, false)
    
    if get_in(edge, [:metadata, :deleted]) do
      # It's a deletion operation - delegate to delete_edge
      delete_edge(store_name, edge.id)
    else
      # Normal insert operation
      # Use the standard do_insert_record function which will handle indices for edges
      result = if compressed, do: do_insert_record(store_name, edge), else: do_insert_record(store_name, edge)
      
      # Invalidate any cached queries after successful insertion
      case result do
        {:ok, _} ->
          # Invalidate any cached queries that might be affected by this edge
          if edge_type = Map.get(edge, :type) do
            invalidate_edge_cache(store_name, edge.source, edge_type)
          end
          result
        _ ->
          result
      end
    end
  end
  
  # Modify delete_edge to invalidate cache when necessary
  def delete_edge(store_name, edge_id) do
    # Find the edge first to get its details for cache invalidation
    case get(store_name, :edge, edge_id) do
      {:ok, edge} ->
        # Track the type for cache invalidation
        edge_type = Map.get(edge, :type)
        source = edge.source
        
        # Perform the standard deletion
        result = do_delete_record(store_name, GraphOS.Entity.Edge, edge_id)
        
        # Invalidate cache if needed after successful deletion
        case result do
          {:ok, _} ->
            if edge_type do
              invalidate_edge_cache(store_name, source, edge_type)
            end
            result
          _ -> result
        end
        
      error -> error
    end
  end
end
