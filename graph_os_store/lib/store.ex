defmodule GraphOS.Store do
  @moduledoc """
  The main entrypoint for storing data or state for GraphOS.Core modules.

  This module provides a minimal interface for storing and retrieving data
  using different storage engines (adapters).
  """

  use Boundary,
  deps: [GraphOS.Entity],
    exports: [

    ]

  @adapter Application.compile_env(__MODULE__, :adapter, GraphOS.Store.Adapter.ETS)

  @doc """
  Initializes a store with the given options.

  ## Parameters

  - `opts` - Options for initializing the store
    - `:adapter` - The storage adapter to use (default: GraphOS.Store.Adapter.ETS)
    - `:name` - Name for the store (default: :default)
    - `:schema_module` - Schema module to use (optional)
    - All other options are forwarded to the adapter

  ## Examples

      iex> GraphOS.Store.init()
      {:ok, :default}

      iex> GraphOS.Store.init(adapter: MyAdapter, name: :my_store)
      {:ok, :my_store}
  """
  @spec init(Keyword.t()) :: {:ok, atom()} | {:error, term()}
  def init(opts \\ []) do
  adapter = Keyword.get(opts, :adapter, @adapter)
  name = Keyword.get(opts, :name, :default)
  schema_module = Keyword.get(opts, :schema_module)

  # Forward all options to adapter init
  adapter_opts =
    opts
    |> Keyword.delete(:adapter)
    |> Keyword.delete(:name)
    |> Keyword.delete(:schema_module)

  with {:ok, _} <- adapter.init(name, adapter_opts) do
    if schema_module do
      :ok = adapter.register_schema(name, schema_module.schema())
    end
    {:ok, name}
  end

  end

  @doc """
  Inserts a new entity into the store.

  ## Parameters

  - `module` - The entity module (e.g., GraphOS.Core.Access.Actor)
  - `data` - The data to insert

  ## Examples

      iex> GraphOS.Store.insert(MyApp.User, %{name: "John", email: "john@example.com"})
      {:ok, %MyApp.User{id: "user1", name: "John", email: "john@example.com"}}
  """
  @spec insert(module(), map()) :: {:ok, map()} | {:error, term()}
  def insert(module, data) do
    @adapter.insert(module, data)
  end

  @doc """
  Updates an existing entity in the store.

  ## Parameters

  - `module` - The entity module (e.g., GraphOS.Core.Access.Actor)
  - `data` - The data to update (must include id)

  ## Examples

      iex> GraphOS.Store.update(MyApp.User, %{id: "user1", name: "John Updated"})
      {:ok, %MyApp.User{id: "user1", name: "John Updated"}}
  """
  @spec update(module(), map()) :: {:ok, map()} | {:error, term()}
  def update(module, data) do
    @adapter.update(module, data)
  end

  @doc """
  Deletes an entity from the store.

  ## Parameters

  - `module` - The entity module (e.g., GraphOS.Core.Access.Actor)
  - `id` - ID of the entity to delete

  ## Examples

      iex> GraphOS.Store.delete(MyApp.User, "user1")
      :ok
  """
  @spec delete(module(), binary()) :: :ok | {:error, term()}
  def delete(module, id) do
    @adapter.delete(module, id)
  end

  @doc """
  Gets an entity from the store by ID.

  ## Parameters

  - `module` - The entity module (e.g., GraphOS.Core.Access.Actor)
  - `id` - ID of the entity to get

  ## Examples

      iex> GraphOS.Store.get(MyApp.User, "user1")
      {:ok, %MyApp.User{id: "user1", name: "John"}}
  """
  @spec get(module(), binary()) :: {:ok, map()} | {:error, term()}
  def get(module, id) do
    @adapter.get(module, id)
  end

  @doc """
  Retrieves all entities of a specified type from the store.

  ## Parameters

  - `module` - The entity module (e.g., GraphOS.Core.Access.Actor)
  - `filter` - Optional map of property names to values for filtering (default: %{})
  - `opts` - Options for the operation
    - `:limit` - Maximum number of results to return
    - `:offset` - Number of results to skip
    - `:sort` - Sort order (default: :desc, uses UUIDv7 sort)

  ## Examples

      iex> GraphOS.Store.all(MyApp.User)
      {:ok, [%MyApp.User{id: "user1", name: "John"}, %MyApp.User{id: "user2", name: "Jane"}]}

      iex> GraphOS.Store.all(MyApp.User, %{role: "admin"})
      {:ok, [%MyApp.User{id: "user1", name: "John", role: "admin"}]}

      iex> GraphOS.Store.all(MyApp.User, %{}, limit: 10, offset: 20)
      {:ok, [%MyApp.User{}, ...]}
  """
  @spec all(module(), map(), Keyword.t()) :: {:ok, list(term())} | {:error, term()}
  def all(module, filter \\ %{}, opts \\ []) do
    @adapter.all(module, filter, opts)
  end

  @doc """
  Executes a graph algorithm traversal on the store.

  ## Parameters

  - `algorithm` - The algorithm to execute, one of:
    - `:bfs` - Breadth-First Search
    - `:connected_components` - Connected Components
    - `:minimum_spanning_tree` - Minimum Spanning Tree
    - `:page_rank` - PageRank
    - `:shortest_path` - Shortest Path
  - `params` - The parameters required for the algorithm:
    - For `:bfs`: `{start_node_id, opts}`
    - For `:connected_components`: `opts`
    - For `:minimum_spanning_tree`: `opts`
    - For `:page_rank`: `opts`
    - For `:shortest_path`: `{source_node_id, target_node_id, opts}`

  ## Examples

      iex> GraphOS.Store.traverse(:bfs, {"node1", max_depth: 3})
      {:ok, [%Node{id: "node1"}, %Node{id: "node2"}, ...]}

      iex> GraphOS.Store.traverse(:shortest_path, {"node1", "node5", weight_property: "distance"})
      {:ok, [%Node{id: "node1"}, %Node{id: "node3"}, %Node{id: "node5"}], 12.5}

      iex> GraphOS.Store.traverse(:connected_components, [])
      {:ok, [[%Node{id: "node1"}, %Node{id: "node2"}], [%Node{id: "node3"}]]}
  """
  @spec traverse(atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
  def traverse(algorithm, params)

  def traverse(:bfs, {start_node_id, opts}) do
    GraphOS.Store.Algorithm.BFS.execute(start_node_id, opts)
  end

  def traverse(:connected_components, opts) do
    GraphOS.Store.Algorithm.ConnectedComponents.execute(opts)
  end

  def traverse(:minimum_spanning_tree, opts) do
    GraphOS.Store.Algorithm.MinimumSpanningTree.execute(opts)
  end

  def traverse(:page_rank, opts) do
    GraphOS.Store.Algorithm.PageRank.execute(opts)
  end

  def traverse(:shortest_path, {source_node_id, target_node_id, opts}) do
    GraphOS.Store.Algorithm.ShortestPath.execute(source_node_id, target_node_id, opts)
  end

  def traverse(algorithm, _params) do
    {:error, {:unsupported_algorithm, algorithm}}
  end
end
