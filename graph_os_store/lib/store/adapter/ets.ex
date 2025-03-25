defmodule GraphOS.Store.Adapter.ETS do
  @moduledoc """
  ETS adapter for the GraphOS store.
  """

  @behaviour GraphOS.Store.Adapter

  use GenServer

  @tables %{
    graph: :graph_os_graphs,
    node: :graph_os_nodes,
    edge: :graph_os_edges,
    metadata: :graph_os_metadata,
    events: :graph_os_events
  }

  # Client API

  @doc """
  Starts the ETS adapter process with the given name and options.
  """
  @spec start_link(atom(), Keyword.t()) :: GenServer.on_start()
  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Initializes a new ETS store with the given name and options.
  Returns a tuple with the process PID.
  """
  @spec init(atom(), Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def init(name, opts \\ []) do
    case start_link(name, opts) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Inserts a new entity into the store.
  """
  @spec insert(module(), map()) :: {:ok, struct()} | {:error, term()}
  def insert(module, data) do
    with {:ok, table_key} <- get_table_for_module(module),
         {:ok, record} <- prepare_record(module, data) do
      table_name = @tables[table_key]
      # Store with metadata including module name
      storage_record = %{
        id: record.id,
        module: module,
        data: record
      }
      true = :ets.insert(table_name, {record.id, storage_record})
      {:ok, record}
    end
  end

  @doc """
  Updates an existing entity in the store.
  """
  @spec update(module(), map()) :: {:ok, struct()} | {:error, term()}
  def update(module, data) do
    with {:ok, table_key} <- get_table_for_module(module),
         id when is_binary(id) <- Map.get(data, :id),
         {:ok, existing} <- get(module, id),
         merged = Map.merge(existing, data),
         {:ok, record} <- prepare_record(module, merged) do
      table_name = @tables[table_key]
      # Store with metadata including module name
      storage_record = %{
        id: record.id,
        module: module,
        data: record
      }
      true = :ets.insert(table_name, {record.id, storage_record})
      {:ok, record}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Deletes an entity from the store.
  """
  @spec delete(module(), binary()) :: :ok | {:error, term()}
  def delete(module, id) do
    with {:ok, table_key} <- get_table_for_module(module) do
      table_name = @tables[table_key]
      true = :ets.delete(table_name, id)
      :ok
    end
  end

  @doc """
  Gets an entity from the store by ID.
  """
  @spec get(module(), binary()) :: {:ok, struct()} | {:error, term()}
  def get(module, id) do
    with {:ok, table_key} <- get_table_for_module(module) do
      table_name = @tables[table_key]
      case :ets.lookup(table_name, id) do
        [{^id, storage_record}] ->
          if storage_record.module == module || is_parent_entity_module?(module, storage_record.module) do
            {:ok, storage_record.data}
          else
            {:error, :not_found}
          end
        [] -> {:error, :not_found}
      end
    end
  end

  @doc """
  Retrieves all entities of a specified type from the store.

  When a specific entity module is provided (e.g., GraphOS.Access.Actor),
  it returns only instances of that module.

  When a parent entity type is provided (e.g., GraphOS.Entity.Node),
  it returns all entities of that type regardless of their specific module.
  """
  @spec all(module(), map(), Keyword.t()) :: {:ok, list(struct())} | {:error, term()}
  def all(module, filter \\ %{}, opts \\ []) do
    with {:ok, table_key} <- get_table_for_module(module) do
      table_name = @tables[table_key]

      is_parent = is_parent_entity_module?(module)

      records = :ets.tab2list(table_name)
                |> Enum.map(fn {_id, storage_record} -> storage_record end)
                |> filter_by_module(module, is_parent)
                |> Enum.map(fn storage_record -> storage_record.data end)
                |> apply_filter(filter)
                |> apply_sort(opts[:sort] || :desc)
                |> apply_pagination(opts[:offset] || 0, opts[:limit])

      {:ok, records}
    end
  end

  @doc """
  Executes a graph algorithm traversal on the store.

  This function delegates to the implementations in GraphOS.Store.Algorithm modules.
  """
  @spec traverse(atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
  def traverse(algorithm, params) do
    case algorithm do
      :bfs ->
        {start_node_id, opts} = params
        GraphOS.Store.Algorithm.BFS.execute(start_node_id, opts)

      :connected_components ->
        GraphOS.Store.Algorithm.ConnectedComponents.execute(params)

      :minimum_spanning_tree ->
        GraphOS.Store.Algorithm.MinimumSpanningTree.execute(params)

      :page_rank ->
        GraphOS.Store.Algorithm.PageRank.execute(params)

      :shortest_path ->
        {source_node_id, target_node_id, opts} = params
        GraphOS.Store.Algorithm.ShortestPath.execute(source_node_id, target_node_id, opts)

      _ ->
        {:error, {:unsupported_algorithm, algorithm}}
    end
  end

  @doc """
  Registers a schema with the store.
  """
  @spec register_schema(atom(), map()) :: :ok | {:error, term()}
  def register_schema(name, schema) do
    GenServer.call(via_tuple(name), {:register_schema, schema})
  end

  # Server callbacks

  @impl GenServer
  def handle_init(opts) do
    table_opts = [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ]

    tables =
      @tables
      |> Enum.map(fn {_key, name} ->
        case :ets.info(name) do
          :undefined -> :ets.new(name, table_opts)
          _ -> name
        end
      end)

    schema = Keyword.get(opts, :schema)
    state = %{tables: tables, schema: schema}

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_schema, schema}, _from, state) do
    {:reply, :ok, %{state | schema: schema}}
  end

  # Private functions

  defp via_tuple(name) do
    {:via, Registry, {GraphOS.Store.Registry, {__MODULE__, name}}}
  end

  defp get_table_for_module(module) do
    try do
      entity_type = GraphOS.Entity.get_type(module)
      {:ok, entity_type}
    rescue
      # If the module doesn't respond to entity() function or for any other reason
      UndefinedFunctionError ->
        {:ok, :metadata} # fallback for any other entities
      error ->
        {:error, error}
    end
  end

  defp prepare_record(module, data) do
    record = if Map.has_key?(data, :id) do
      data
    else
      Map.put(data, :id, GraphOS.Entity.generate_id())
    end

    # Make sure we return a struct of the proper type
    {:ok, struct(module, record)}
  end

  defp is_parent_entity_module?(module, specific_module \\ nil) do
    parent_modules = [
      GraphOS.Entity.Graph,
      GraphOS.Entity.Node,
      GraphOS.Entity.Edge
    ]

    if specific_module do
      # Check if module is a parent of specific_module
      module in parent_modules &&
        (try do
          GraphOS.Entity.get_type(module) == GraphOS.Entity.get_type(specific_module)
        rescue
          _ -> false
        end)
    else
      # Just check if module is a parent entity type
      module in parent_modules
    end
  end

  defp filter_by_module(records, module, true) do
    # For parent entity types (Node, Edge, Graph), return all entities of that type
    try do
      parent_type = GraphOS.Entity.get_type(module)
      Enum.filter(records, fn record ->
        try do
          GraphOS.Entity.get_type(record.module) == parent_type
        rescue
          _ -> false
        end
      end)
    rescue
      _ -> records
    end
  end

  defp filter_by_module(records, module, false) do
    # For specific entity modules, return only instances of that module
    Enum.filter(records, fn record -> record.module == module end)
  end

  defp apply_filter(records, filter) when map_size(filter) == 0, do: records
  defp apply_filter(records, filter) do
    Enum.filter(records, fn record ->
      Enum.all?(filter, fn {key, value} ->
        Map.get(record, key) == value
      end)
    end)
  end

  defp apply_sort(records, :asc) do
    Enum.sort_by(records, & &1.id)
  end

  defp apply_sort(records, :desc) do
    Enum.sort_by(records, & &1.id, :desc)
  end

  defp apply_pagination(records, offset, nil) do
    records |> Enum.drop(offset)
  end

  defp apply_pagination(records, offset, limit) do
    records |> Enum.drop(offset) |> Enum.take(limit)
  end
end
