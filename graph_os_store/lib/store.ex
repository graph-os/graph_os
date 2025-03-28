defmodule GraphOS.Store do
  @moduledoc """
  The main entrypoint for storing data or state for GraphOS.Core modules.

  Provides a mechanism to define and interact with named stores,
  each backed by a configurable adapter process.

  ## Defining Stores

  Stores can be defined at compile-time using `use GraphOS.Store`:

      defmodule MyApp.Store do
        use GraphOS.Store,
          adapter: GraphOS.Store.Adapter.ETS, # Or your custom adapter
          otp_app: :my_app # Optional: helps locate adapter config
          # Other adapter-specific options...
      end

      MyApp.Store.insert(MyEntity, %{...})

  This creates a store named `MyApp.Store`.

  ## Default Store

  The `GraphOS.Store` module itself provides functions that operate on a
  default store named `:default`. This store must be configured in your
  application's config:

      config :graph_os_store, GraphOS.Store,
        adapter: GraphOS.Store.Adapter.ETS
        # ...other default adapter options

  And started in your supervision tree:

      # In application.ex
      children = [
        {GraphOS.Store, name: :default} # Start the default store
        # ... other children
      ]

      GraphOS.Store.insert(MyEntity, %{...}) # Uses :default store

  ## Dynamic Stores

  Stores can also be started dynamically:

      {:ok, pid} = GraphOS.Store.start_link(name: "temp_cache", adapter: SomeAdapter)
      GraphOS.Store.insert("temp_cache", MyEntity, %{...})

  """

  use Boundary, deps: [GraphOS.Entity]

  require Logger
  alias GraphOS.Store.Registry

  # Define the default store name here
  @default_store_name :default

  # --- Public API for Dynamic/Explicit Stores ---

  @doc """
  Starts a store adapter process dynamically and registers it.

  Options are passed down to the adapter's `start_link`.
  The `:name` option is required to identify the store.
  The `:adapter` option specifies the adapter module.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    adapter = Keyword.fetch!(opts, :adapter)
    adapter_opts = Keyword.delete(opts, :adapter)

    # Start the adapter process - rely on adapter's :via for registration
    case adapter.start_link(name, adapter_opts) do
      {:ok, pid} ->
        # Registration handled by adapter via :via tuple
        Logger.info(
          "Store '#{name}' started with adapter #{inspect(adapter)} (PID: #{inspect(pid)})"
        )

        {:ok, pid}

      # Capture the original error tuple
      {:error, {:already_started, pid}} = error ->
        # :via tuple in adapter handles this case. If start_link returns {:error, {:already_started, pid}},
        # it means the GenServer machinery (using Registry) found an existing process.
        Logger.info("Store '#{name}' already started and registered (PID: #{inspect(pid)})")
        # IMPORTANT: Return the original error tuple for supervisors
        error

      {:error, reason} = error ->
        Logger.error(
          "Failed to start adapter #{inspect(adapter)} for store '#{name}': #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Stops a dynamically started store adapter process and unregisters it.
  """
  @spec stop(store_ref :: term()) :: :ok | :error
  def stop(store_ref) do
    case Registry.lookup(store_ref) do
      [{pid, _}] ->
        # Unregister first
        Registry.unregister(store_ref)
        # Then terminate the process
        GenServer.stop(pid)

      [] ->
        # Store not found or already stopped
        :ok
    end
  end

  # --- Insert Operations ---

  @doc """
  Inserts a new entity into the specified store.
  """
  @spec insert(store_ref :: term(), module(), map()) :: {:ok, struct()} | {:error, term()}
  def insert(store_ref, module, data) do
    call_adapter(store_ref, {:insert, module, data})
  end

  @doc """
  Inserts a new entity into the default store (`#{@default_store_name}`).
  """
  @spec insert(module(), map()) :: {:ok, struct()} | {:error, term()}
  def insert(module, data) do
    insert(@default_store_name, module, data)
  end

  # --- Update Operations ---

  @doc """
  Updates an existing entity in the specified store.
  """
  @spec update(store_ref :: term(), module(), map()) :: {:ok, struct()} | {:error, term()}
  def update(store_ref, module, data) do
    call_adapter(store_ref, {:update, module, data})
  end

  @doc """
  Updates an existing entity in the default store (`#{@default_store_name}`).
  """
  @spec update(module(), map()) :: {:ok, struct()} | {:error, term()}
  def update(module, data) do
    update(@default_store_name, module, data)
  end

  # --- Delete Operations ---

  @doc """
  Deletes an entity from the specified store.
  """
  @spec delete(store_ref :: term(), module(), binary()) :: :ok | {:error, term()}
  def delete(store_ref, module, id) do
    call_adapter(store_ref, {:delete, module, id})
  end

  @doc """
  Deletes an entity from the default store (`#{@default_store_name}`).
  """
  @spec delete(module(), binary()) :: :ok | {:error, term()}
  def delete(module, id) do
    delete(@default_store_name, module, id)
  end

  # --- Get Operations ---

  @doc """
  Gets an entity from the specified store by ID.
  """
  @spec get(store_ref :: term(), module(), binary()) :: {:ok, struct()} | {:error, term()}
  def get(store_ref, module, id) do
    call_adapter(store_ref, {:get, module, id})
  end

  @doc """
  Gets an entity from the default store (`#{@default_store_name}`) by ID.
  """
  @spec get(module(), binary()) :: {:ok, struct()} | {:error, term()}
  def get(module, id) do
    get(@default_store_name, module, id)
  end

  # --- Query operations ---

  @doc """
  Gets all entities of the specified type from the store that match the filter.

  ## Examples

      # With default store
      iex> GraphOS.Store.all(GraphOS.Entity.Node, %{type: "document"})
      {:ok, [%Node{...}, %Node{...}]}

      # With named store
      iex> GraphOS.Store.all(:my_store, GraphOS.Entity.Node, %{type: "document"})
      {:ok, [%Node{...}, %Node{...}]}

      # With options
      iex> GraphOS.Store.all(:my_store, GraphOS.Entity.Node, %{type: "document"}, limit: 10)
      {:ok, [%Node{...}, %Node{...}]}
  """
  @spec all(term(), module(), map()) :: {:ok, [struct()]} | {:error, term()}
  @spec all(term(), module(), map(), Keyword.t()) :: {:ok, [struct()]} | {:error, term()}
  @spec all(module(), map()) :: {:ok, [struct()]} | {:error, term()}
  @spec all(module(), map(), Keyword.t()) :: {:ok, [struct()]} | {:error, term()}
  def all(store_ref, module, filter, opts)
      when is_atom(module) and is_map(filter) and is_list(opts) do
    call_adapter(store_ref, {:all, module, filter, opts})
  end

  def all(store_ref, module, filter) when is_atom(module) and is_map(filter) do
    all(store_ref, module, filter, [])
  end

  def all(module, filter, opts) when is_atom(module) and is_map(filter) and is_list(opts) do
    all(@default_store_name, module, filter, opts)
  end

  def all(module, filter) when is_atom(module) and is_map(filter) do
    all(@default_store_name, module, filter)
  end

  # --- Register Schema Operations ---

  @doc """
  Registers a schema with the specified store.
  """
  @spec register_schema(store_ref :: term(), map()) :: :ok | {:error, term()}
  def register_schema(store_ref, schema) do
    call_adapter(store_ref, {:register_schema, schema})
  end

  @doc """
  Registers a schema with the default store (`#{@default_store_name}`).
  """
  @spec register_schema(map()) :: :ok | {:error, term()}
  def register_schema(schema) do
    register_schema(@default_store_name, schema)
  end

  # --- Traverse Operations ---

  @doc """
  Executes a graph algorithm traversal on the specified store.
  """
  @spec traverse(store_ref :: term(), atom(), tuple() | list()) ::
          {:ok, term()} | {:error, term()}
  def traverse(store_ref, algorithm, params) do
    call_adapter(store_ref, {:traverse, algorithm, params})
  end

  @doc """
  Executes a graph algorithm traversal on the default store (`#{@default_store_name}`).
  """
  @spec traverse(atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
  def traverse(algorithm, params) do
    traverse(@default_store_name, algorithm, params)
  end

  # --- Private Utilities ---

  @doc false
  defp call_adapter(store_ref, call_args) do
    case Registry.lookup(store_ref) do
      [{pid, _}] ->
        case GenServer.call(pid, call_args) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
          other -> other
        end

      [] ->
        {:error, {:store_not_found, store_ref}}
    end
  rescue
    error in [RuntimeError, ArgumentError, KeyError] ->
      reraise(error, __STACKTRACE__)

    _ ->
      {:error, {:internal_error, store_ref}}
  end

  defmacro __using__(opts) do
    quote do
      # Store the configuration for potential use at startup
      @graph_os_store_opts unquote(opts)
      @store_name Keyword.get(unquote(opts), :name, __MODULE__)

      # Add the store to the app's supervision tree
      # This will generate a child_spec but users must add it to their supervision tree
      def child_spec(args) do
        default_args = %{
          id: __MODULE__,
          start:
            {GraphOS.Store, :start_link,
             [
               [
                 name: @store_name,
                 adapter: Keyword.get(@graph_os_store_opts, :adapter, GraphOS.Store.Adapter.ETS),
                 otp_app: Keyword.get(@graph_os_store_opts, :otp_app)
               ] ++ Keyword.drop(@graph_os_store_opts, [:adapter, :name, :otp_app])
             ]}
        }

        Supervisor.child_spec(Map.merge(default_args, args), [])
      end

      # --- Instance API ---

      @doc """
      Inserts a new entity into the `#{@store_name}` store.
      """
      @spec insert(module(), map()) :: {:ok, struct()} | {:error, term()}
      def insert(module, data) do
        GraphOS.Store.insert(@store_name, module, data)
      end

      @doc """
      Updates an existing entity in the `#{@store_name}` store.
      """
      @spec update(module(), map()) :: {:ok, struct()} | {:error, term()}
      def update(module, data) do
        GraphOS.Store.update(@store_name, module, data)
      end

      @doc """
      Deletes an entity from the `#{@store_name}` store.
      """
      @spec delete(module(), binary()) :: :ok | {:error, term()}
      def delete(module, id) do
        GraphOS.Store.delete(@store_name, module, id)
      end

      @doc """
      Gets an entity from the `#{@store_name}` store by ID.
      """
      @spec get(module(), binary()) :: {:ok, struct()} | {:error, term()}
      def get(module, id) do
        GraphOS.Store.get(@store_name, module, id)
      end

      # Group all/1, all/2, all/3 with clear pattern matching

      @doc """
      Retrieves all entities of a specified type from the `#{@store_name}` store.
      """
      @spec all(module()) :: {:ok, list(struct())} | {:error, term()}
      def all(module) when is_atom(module) do
        GraphOS.Store.all(@store_name, module)
      end

      @doc """
      Retrieves all entities of a specified type from the `#{@store_name}` store with filter.
      """
      @spec all(module(), map()) :: {:ok, list(struct())} | {:error, term()}
      def all(module, filter) when is_atom(module) and is_map(filter) do
        GraphOS.Store.all(@store_name, module, filter)
      end

      @doc """
      Retrieves all entities of a specified type from the `#{@store_name}` store with filter and options.
      """
      @spec all(module(), map(), Keyword.t()) :: {:ok, list(struct())} | {:error, term()}
      def all(module, filter, opts) when is_atom(module) and is_map(filter) and is_list(opts) do
        GraphOS.Store.all(@store_name, module, filter, opts)
      end

      @doc """
      Registers a schema with the `#{@store_name}` store.
      """
      @spec register_schema(map()) :: :ok | {:error, term()}
      def register_schema(schema) do
        GraphOS.Store.register_schema(@store_name, schema)
      end

      @doc """
      Executes a graph algorithm traversal on the `#{@store_name}` store.
      """
      @spec traverse(atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
      def traverse(algorithm, params) do
        GraphOS.Store.traverse(@store_name, algorithm, params)
      end

      # --- Admin API ---

      @doc """
      Gets the runtime configuration of this store.
      """
      def config do
        # TBD: Implement a way to fetch runtime config
        @graph_os_store_opts
      end

      @doc """
      Gets the current status of this store.
      """
      def status do
        case GraphOS.Store.Registry.lookup(@store_name) do
          [{pid, _}] -> {:ok, {__MODULE__, pid, Process.info(pid, :status)}}
          [] -> {:error, :not_running}
        end
      end
    end
  end
end
