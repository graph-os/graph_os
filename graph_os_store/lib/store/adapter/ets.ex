defmodule GraphOS.Store.Adapter.ETS do
  @moduledoc """
  ETS adapter for the GraphOS store.

  This adapter uses ETS tables for in-memory storage.
  Each store instance manages its own set of ETS tables named
  with the pattern `:<store_name>_<table>` (e.g., `:default_nodes`).
  """

  @behaviour GraphOS.Store.Adapter

  use GenServer
  require Logger
  alias GraphOS.Store.Registry

  # Store name will be prefixed to these base names
  @base_table_names %{
    graph: :graphs,
    node: :nodes,
    edge: :edges,
    events: :events
  }

  @base_entities [
    GraphOS.Entity.Graph,
    GraphOS.Entity.Node,
    GraphOS.Entity.Edge
  ]
  defguard is_base_entity?(module) when module in @base_entities

  # --- GenServer Lifecycle ---

  @doc false
  # Called by GraphOS.Store.start_link
  @spec start_link(name :: term(), opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(name, opts \\ []) do
    # Use Registry for process registration
    GenServer.start_link(__MODULE__, {name, opts}, name: via_tuple(name))
  end

  @impl GenServer
  def init({name, opts}) do
    schema = Keyword.get(opts, :schema)
    Logger.debug("Initializing ETS adapter for store '#{name}'")
    # Defer table creation until after process registration
    {:ok, %{name: name, schema: schema, tables: %{}}, {:continue, :init_tables}}
  end

  @impl GenServer
  def handle_continue(:init_tables, state) do
    %{name: name} = state
    Logger.debug("Creating/Verifying ETS tables for store '#{name}'")
    table_opts = [
      :set,
      :public, # Or :protected
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ]

    tables_map =
      @base_table_names
      |> Enum.into(%{}, fn {type, _base_name} ->
        table_name = make_table_name(name, type)
        ets_table_ref = # Use table_name as the reference after creation/check
          case :ets.info(table_name) do
            :undefined ->
              Logger.debug("Creating ETS table '#{table_name}' for store '#{name}'")
              :ets.new(table_name, table_opts)
              table_name # Store the name as the reference
            _tid -> # Check if it's already a known table
              Logger.debug("Using existing ETS table '#{table_name}' for store '#{name}'")
              table_name # Store the name as the reference
          end
        {type, ets_table_ref} # Store type -> table_name mapping
      end)

    new_state = %{state | tables: tables_map}
    {:noreply, new_state}
  end

  # --- Adapter Behaviour Callbacks (Public API) ---
  # These functions find the correct GenServer via Registry and delegate.

  @impl GraphOS.Store.Adapter
  def register_schema(store_ref, schema) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:register_schema, schema})
  end

  @impl GraphOS.Store.Adapter
  def insert(store_ref, module, data) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:insert, module, data})
  end

  @impl GraphOS.Store.Adapter
  def update(store_ref, module, data) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:update, module, data})
  end

  @impl GraphOS.Store.Adapter
  def delete(store_ref, module, id) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:delete, module, id})
  end

  @impl GraphOS.Store.Adapter
  def get(store_ref, module, id) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:get, module, id})
  end

  @impl GraphOS.Store.Adapter
  def all(store_ref, module, filter \\ %{}, opts \\ []) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:all, module, filter, opts})
  end

  @impl GraphOS.Store.Adapter
  def traverse(store_ref, algorithm, params) do
    pid = Registry.lookup!(store_ref)
    GenServer.call(pid, {:traverse, algorithm, params})
  end

  # --- GenServer Call Handlers (Core Logic) ---

  @impl GenServer
  def handle_call({:register_schema, schema}, _from, state) do
    {:reply, :ok, %{state | schema: schema}}
  end

  @impl GenServer
  def handle_call({:insert, module, data}, _from, state) do
    # Use state.name for operations
    store_name = state.name
    result =
      with {:ok, struct_data} <- {:ok, ensure_struct!(module, data)},
           {:ok, record} <- ensure_new_id!(store_name, struct_data),
           {:ok, record} <- do_insert_record(store_name, record) do
        {:ok, record}
      else
        {:error, reason} -> {:error, reason}
        # Handle potential error from ensure_struct! if it were to return error tuple
        # error -> error
      end
    {:reply, result, state}
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
        # error -> error
      end
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:delete, module, id}, _from, state) do
    store_name = state.name
    result = case do_delete_record(store_name, module, id) do
      {:ok, _deleted_record} -> :ok # Return :ok on successful soft delete
      {:error, {:not_found, _reason}} -> :ok # Idempotent: deleting non-existent is OK
      {:error, other_error} -> {:error, other_error} # Propagate other errors
    end
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get, module, id}, _from, state) do
    store_name = state.name
    result = do_read_record(store_name, module, id) # read_record now handles the 'deleted' check
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
    # Note: Algorithms might need the store_name or need refactoring
    # if they directly interact with ETS instead of going via the Store API.
    # Assuming they use Store API calls which will route back here correctly.
    store_name = state.name
    result = do_traverse(store_name, algorithm, params)
    {:reply, result, state}
  end

  # --- Private Helper Functions (Core Logic Implementation) ---

  # Renamed internal helpers to do_* to avoid clash with public API

  @spec do_insert_record(atom(), struct()) :: {:ok, struct()} | {:error, term()}
  defp do_insert_record(store_name, %{__struct__: module, id: id} = record) do
    table_name = get_table_name_from_state!(store_name, module) # Use helper based on type
    now = DateTime.utc_now()
    
    # Get entity type safely using our helper
    entity_type = case safe_get_type(module) do
      {:ok, type} -> type
      {:error, _} -> :unknown # Fallback to unknown if type can't be determined
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

    case :ets.insert(table_name, {id, record_with_metadata}) do
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

  @spec do_delete_record(atom(), module(), binary()) :: {:ok, struct()} | {:error, term()}
  defp do_delete_record(store_name, module, id) do
    table_name = get_table_name_from_state!(store_name, module)
    case :ets.lookup(table_name, id) do
      [{^id, %{metadata: old_metadata} = existing_record}] when not old_metadata.deleted ->
        now = DateTime.utc_now()
        new_metadata = %GraphOS.Entity.Metadata{old_metadata |
          updated_at: now,
          deleted_at: now,
          deleted: true,
          version: old_metadata.version + 1
        }
        deleted_record = Map.put(existing_record, :metadata, new_metadata)

        case :ets.insert(table_name, {id, deleted_record}) do
          true -> {:ok, deleted_record}
          false -> {:error, {:ets_delete_failed, table_name, id}}
        end
      [{^id, %{metadata: %{deleted: true}} = deleted_record}] -> # Match already deleted
        {:ok, deleted_record} # Idempotent
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
      all_tuples = :ets.tab2list(table_name)

      records = Enum.reduce(all_tuples, [], fn {_id, record}, acc ->
        if record.metadata.deleted do
          acc
        else
          [record | acc]
        end
      end)

      is_parent = is_base_entity?(module)
      filtered_by_module = filter_by_module(records, module, is_parent)

      results = filtered_by_module
                |> apply_filter(filter)
                |> apply_sort(opts[:sort] || :desc)
                |> apply_pagination(opts[:offset] || 0, opts[:limit])

      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
      # Handle case where table name couldn't be determined (e.g., invalid module type)
    end
  end

  @spec do_traverse(atom(), atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
  defp do_traverse(store_name, algorithm, params) do
    # This implementation assumes Algorithm modules use GraphOS.Store API calls
    # which will route back to the correct store instance.
    # If Algorithms need direct ETS access, they would need the store_name/
    # table names passed explicitly, or this function would need to provide
    # access/context based on the store_name.
    case algorithm do
      :bfs ->
        {start_node_id, opts} = params
        # Pass the store_name to the BFS algorithm
        GraphOS.Store.Algorithm.BFS.execute(store_name, {start_node_id, opts})
      :connected_components ->
        GraphOS.Store.Algorithm.ConnectedComponents.execute(params)
      :minimum_spanning_tree ->
        GraphOS.Store.Algorithm.MinimumSpanningTree.execute(params)
      :page_rank ->
        GraphOS.Store.Algorithm.PageRank.execute(params)
      :shortest_path ->
        {source_node_id, target_node_id, opts} = params
        # Make sure the store name is in the options
        opts_with_store = Keyword.put(opts, :store, store_name)
        GraphOS.Store.Algorithm.ShortestPath.execute(source_node_id, target_node_id, opts_with_store)
      _ ->
        {:error, {:unsupported_algorithm, algorithm}}
    end
    # Consider adding try/rescue block for algorithm execution
  end

  # --- Utility Functions --- Requires store_name passed from state ---

  # Removed get_store_name/0

  @spec make_table_name(store_name :: term(), type :: atom()) :: atom()
  defp make_table_name(store_name, type) do
    base_name = @base_table_names[type] ||
      raise "Invalid entity type for ETS table name: #{inspect(type)}"
    String.to_atom("#{store_name}_#{base_name}")
  end

  @spec get_table_name_from_state!(store_name :: term(), module()) :: atom()
  defp get_table_name_from_state!(store_name, module) do
    # Safely get the type, with better error handling
    type = case safe_get_type(module) do
      {:ok, entity_type} when entity_type in [:node, :edge, :graph] -> entity_type
      {:error, reason} -> raise "Failed to get entity type for #{inspect module}: #{inspect reason}"
    end
    make_table_name(store_name, type)
  end

  # Variation returning {:ok, name} | {:error, _}
  @spec get_table_name_from_state(store_name :: term(), module()) :: {:ok, atom()} | {:error, term()}
  defp get_table_name_from_state(store_name, module) do
    try do
      type = case safe_get_type(module) do
        {:ok, entity_type} when entity_type in [:node, :edge, :graph] -> entity_type
        {:error, reason} -> raise "Failed to get entity type for #{inspect module}: #{inspect reason}"
      end
      {:ok, make_table_name(store_name, type)}
    catch
      kind, reason ->
        # Log the error for debugging purposes
        Logger.error("Failed to determine table name for #{inspect module}: #{kind} #{inspect reason}")
        {:error, {:get_type_failed, module, kind, reason}}
    end
  end

  # Helper function to safely get the entity type
  @spec safe_get_type(module()) :: {:ok, GraphOS.Entity.entity_type()} | {:error, term()}
  defp safe_get_type(module) do
    try do
      # Special case for Graph module which we know is a graph entity
      if module == GraphOS.Entity.Graph do
        {:ok, :graph}
      else
        # Safely handle various return values from module.entity()
        result = module.entity()
        type = case result do
          keywords when is_list(keywords) -> Keyword.get(keywords, :entity_type)
          %{entity_type: type} -> type  # Handle map returns
          %GraphOS.Entity{entity_type: type} -> type  # Handle Entity struct
          _ -> nil # Handle other unexpected return types
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

  @spec ensure_new_id!(atom(), struct()) :: {:ok, struct()} | {:error, term()}
  defp ensure_new_id!(store_name, %{id: id, __struct__: module} = record) do
    table_name = get_table_name_from_state!(store_name, module)
    if :ets.member(table_name, id) do
      {:error, {:id_already_exists, id, table_name}}
    else
      {:ok, record}
    end
  end

  @spec ensure_existing_id!(atom(), struct()) :: {:ok, struct()} | {:error, term()}
  defp ensure_existing_id!(store_name, %{id: id, __struct__: module} = record) do
    table_name = get_table_name_from_state!(store_name, module)
    case :ets.lookup(table_name, id) do
      [{^id, _existing_record}] -> {:ok, record}
      [] -> {:error, {:not_found, "Record #{id} not found in #{table_name}"}}
    end
  end

  defp via_tuple(name) do
    {:via, GraphOS.Store.Registry, name} # Use Registry directly
  end

  # filter_by_module remains the same
  defp filter_by_module(records, _module, true), do: records
  defp filter_by_module(records, module, false) do
    Enum.filter(records, fn record -> record.metadata.module == module end)
  end

  # apply_filter remains the same
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

  # apply_sort remains the same
  defp apply_sort(records, :asc), do: Enum.sort_by(records, & &1.id)
  defp apply_sort(records, :desc), do: Enum.sort_by(records, & &1.id, :desc)

  # apply_pagination remains the same
  defp apply_pagination(records, offset, nil) when is_integer(offset) and offset >= 0, do: Enum.drop(records, offset)
  defp apply_pagination(records, offset, limit) when is_integer(offset) and offset >= 0 and is_integer(limit) and limit >= 0, do: records |> Enum.drop(offset) |> Enum.take(limit)
  defp apply_pagination(records, _offset, _limit) do
    Logger.warning("Invalid pagination options received. Returning all records.")
    records
  end
end
