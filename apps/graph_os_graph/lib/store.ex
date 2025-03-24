defmodule GraphOS.Store do
  @moduledoc """
  The main entrypoint for storing data or state for GraphOS.Core modules.

  This module provides a minimal interface for storing and retrieving data
  using different storage engines (adapters).
  """

  use Boundary,
    exports: [
      GraphOS.Store.Graph,
      GraphOS.Store.Node,
      GraphOS.Store.Edge,
      GraphOS.Store.StoreAdapter,
      GraphOS.Store.Operation,
      GraphOS.Store.Query,
      GraphOS.Store.Registry,
      GraphOS.Store.Schema
    ]

  alias GraphOS.Store.{StoreAdapter, Operation, Query, Registry}

  @doc """
  Initializes a store with the given options.

  ## Parameters

  - `opts` - Options for initializing the store
    - `:adapter` - The storage adapter to use
    - `:name` - Name for the store
    - `:schema_module` - Schema module to use (optional)
    - All other options are forwarded to the adapter

  ## Examples

      iex> GraphOS.Store.init(adapter: MyAdapter, name: :my_store)
      {:ok, :my_store}
  """
  @spec init(Keyword.t()) :: {:ok, atom()} | {:error, term()}
  def init(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    name = Keyword.fetch!(opts, :name)

    # Initialize adapter with schema_module if provided
    case StoreAdapter.init(adapter, opts) do
      {:ok, store_ref} ->
        Registry.register(name, store_ref, adapter)
        {:ok, name}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Starts the store and registers it in the registry.

  ## Parameters

  - `opts` - Options for starting the store
    - `:adapter` - The storage adapter to use (default: GraphOS.Store.StoreAdapter.ETS)
    - `:name` - Name for the store (default: :default)

  ## Examples

      iex> GraphOS.Store.start()
      {:ok, :default}

      iex> GraphOS.Store.start(adapter: MyCustomAdapter)
      {:ok, :my_custom_adapter}
  """
  @spec start(Keyword.t()) :: {:ok, atom()} | {:error, term()}
  def start(opts \\ []) do
    adapter = Keyword.get(opts, :adapter, GraphOS.Store.StoreAdapter.ETS)
    name = Keyword.get(opts, :name, :default)

    case StoreAdapter.init(adapter) do
      {:ok, store_ref} ->
        Registry.register(name, store_ref, adapter)
        {:ok, name}

      # DEPRECATED: Remove this once we've migrated all users to the new Store API
      # It is left here as a note not to ADD IT BACK. We should rather
      # update all modules to use the proper API
      # :ok ->
      #   # Handle legacy return value
      #   Registry.register(name, nil, adapter)
      #   :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stops the store and unregisters it from the registry.

  ## Parameters

  - `name` - Name of the store to stop (default: :default)

  ## Examples

      iex> GraphOS.Store.stop()
      :ok
  """
  @spec stop(atom()) :: :ok | {:error, term()}
  def stop(name \\ :default) do
    case Registry.lookup(name) do
      {:ok, store_ref, adapter} ->
        result = StoreAdapter.stop(adapter, store_ref)
        Registry.unregister(name)
        result

      {:error, :not_found} ->
        {:error, :store_not_found}
    end
  end

  @doc """
  Executes an operation, query or transaction against the store.

  ## Parameters

  - `operation` - The operation, query or transaction to execute
  - `opts` - Options for execution
    - `:store` - The store name to use (default: :default)

  ## Examples

      iex> operation = %Operation{type: :insert, entity: :node, params: %{id: "node1", type: "person"}}
      iex> GraphOS.Store.execute(operation)
      {:ok, %Node{id: "node1", type: "person"}}

      iex> query = %Query{type: :get, entity: :node, params: %{id: "node1"}}
      iex> GraphOS.Store.execute(query)
      {:ok, %Node{id: "node1", type: "person"}}

      iex> transaction = %Transaction{operations: [op1, op2]}
      iex> GraphOS.Store.execute(transaction)
      {:ok, [result1, result2]}
  """
  @spec execute(struct(), Keyword.t()) :: {:ok, term()} | {:error, term()}
  def execute(operation, opts \\ []) do
    store_name = Keyword.get(opts, :store, :default)

    case Registry.lookup(store_name) do
      {:ok, store_ref, adapter} ->
        StoreAdapter.execute(adapter, store_ref, operation)

      {:error, :not_found} ->
        {:error, :store_not_found}
    end
  end

  @doc """
  Inserts a new Graph, Node, or Edge into the store.

  ## Parameters

  - `entity_type` - The type of entity to insert (:graph, :node, or :edge)
  - `params` - Parameters for the entity
  - `opts` - Options for the insertion
    - `:store` - The store name to use (default: :default)

  ## Examples

      iex> GraphOS.Store.insert(:node, %{id: "node1", type: "person"})
      {:ok, %Node{id: "node1", type: "person"}}

      iex> GraphOS.Store.insert(:edge, %{id: "edge1", source: "node1", target: "node2"})
      {:ok, %Edge{id: "edge1", source: "node1", target: "node2"}}

      iex> GraphOS.Store.insert(:graph, %{id: "graph1", name: "My Graph"})
      {:ok, %Graph{id: "graph1", name: "My Graph"}}
  """
  @spec insert(atom(), map(), Keyword.t()) :: {:ok, term()} | {:error, term()}
  def insert(entity_type, params, opts \\ []) do
    operation = %Operation{type: :insert, entity: entity_type, params: params}
    execute(operation, opts)
  end

  @doc """
  Updates an existing Graph, Node, or Edge in the store.

  ## Parameters

  - `entity_type` - The type of entity to update (:graph, :node, or :edge)
  - `params` - Parameters for the entity, must include the ID
  - `opts` - Options for the update
    - `:store` - The store name to use (default: :default)

  ## Examples

      iex> GraphOS.Store.update(:node, %{id: "node1", name: "Updated Name"})
      {:ok, %Node{id: "node1", name: "Updated Name"}}
  """
  @spec update(atom(), map(), Keyword.t()) :: {:ok, term()} | {:error, term()}
  def update(entity_type, params, opts \\ []) do
    operation = %Operation{type: :update, entity: entity_type, params: params}
    execute(operation, opts)
  end

  @doc """
  Deletes a Graph, Node, or Edge from the store.

  ## Parameters

  - `entity_type` - The type of entity to delete (:graph, :node, or :edge)
  - `id` - ID of the entity to delete
  - `opts` - Options for the deletion
    - `:store` - The store name to use (default: :default)

  ## Examples

      iex> GraphOS.Store.delete(:node, "node1")
      :ok
  """
  @spec delete(atom(), binary(), Keyword.t()) :: :ok | {:error, term()}
  def delete(entity_type, id, opts \\ []) do
    operation = %Operation{type: :delete, entity: entity_type, params: %{id: id}}
    execute(operation, opts)
  end

  @doc """
  Gets a Graph, Node, or Edge from the store by ID.

  ## Parameters

  - `entity_type` - The type of entity to get (:graph, :node, or :edge)
  - `id` - ID of the entity to get
  - `opts` - Options for the get operation
    - `:store` - The store name to use (default: :default)

  ## Examples

      iex> GraphOS.Store.get(:node, "node1")
      {:ok, %Node{id: "node1", type: "person"}}
  """
  @spec get(atom(), binary(), Keyword.t()) :: {:ok, term()} | {:error, term()}
  def get(entity_type, id, opts \\ []) do
    query = Query.get(entity_type, id, opts)
    execute(query)
  end
end
