defmodule GraphOS.Adapter.GraphAdapter do
  @moduledoc """
  Defines the behavior for GraphOS Graph adapters.

  Graph adapters are protocol-specific implementations that translate between
  the GraphOS Graph API and various communication protocols. They allow the Graph
  to be accessed through different interfaces while maintaining consistent semantics.

  ## Adapter Types

  - `GraphOS.Adapter.GenServer`: Direct Elixir integration via GenServer
  - `GraphOS.Adapter.JSONRPC`: JSON-RPC 2.0 protocol adapter
  - `GraphOS.Adapter.MCP`: Model Context Protocol adapter

  ## Implementing an Adapter

  To create a new adapter, define a module that implements the `GraphOS.Adapter.GraphAdapter`
  behavior, or use the `use GraphOS.Adapter.GraphAdapter` macro:

  ```elixir
  defmodule MyAdapter do
    use GraphOS.Adapter.GraphAdapter
    
    @impl true
    def init(opts) do
      # Initialize adapter state
      {:ok, %{config: opts}}
    end
    
    @impl true
    def handle_operation(operation, context, state) do
      # Handle a Graph operation
      case operation do
        {:query, path, params} ->
          # Handle query operation
          result = GraphOS.Graph.query(params)
          {:reply, result, context, state}
          
        {:action, path, params} ->
          # Handle action operation
          result = GraphOS.Graph.execute(build_transaction(params))
          {:reply, result, context, state}
      end
    end
  end
  ```

  ## Adapter Composition with Plugs

  Adapters can be enhanced with middleware using the `GraphOS.Adapter.PlugAdapter` system:

  ```elixir
  # Define the adapter with a pipeline of plugs
  adapter_opts = [
    adapter: MyAdapter,
    plugs: [
      {AuthPlug, realm: "api"},
      LoggingPlug,
      ErrorHandlingPlug
    ]
  ]

  # Start the adapter
  GraphOS.Adapter.GraphAdapter.start_link(adapter_opts)
  ```
  """

  alias GraphOS.Adapter.Context

  @type operation ::
          {:query, path :: String.t(), params :: map()}
          | {:action, path :: String.t(), params :: map()}

  @type handler_response ::
          {:reply, term(), Context.t(), term()}
          | {:noreply, Context.t(), term()}
          | {:error, term(), Context.t(), term()}

  @doc """
  Initializes the adapter.

  This callback is invoked when the adapter is started. It should perform any
  necessary setup and return an initial state.

  ## Parameters

    * `opts` - The options passed when starting the adapter
    
  ## Returns

    * `{:ok, state}` - Successfully initialized with the given state
    * `{:error, reason}` - Failed to initialize
  """
  @callback init(opts :: term()) :: {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Handles a Graph operation.

  This callback processes Graph operations (queries or actions) and returns an
  appropriate response. It receives the operation, a context struct containing
  request data, and the current adapter state.

  ## Parameters

    * `operation` - The operation to perform, either `{:query, path, params}` or `{:action, path, params}`
    * `context` - The current context containing request data
    * `state` - The current adapter state
    
  ## Returns

    * `{:reply, result, context, state}` - Reply with a result and updated context/state
    * `{:noreply, context, state}` - No immediate reply (for async operations)
    * `{:error, reason, context, state}` - Operation failed with the given reason
  """
  @callback handle_operation(operation(), Context.t(), state :: term()) :: handler_response()

  @doc """
  Terminates the adapter.

  This optional callback is invoked when the adapter is about to shut down.
  It can be used to clean up any resources.

  ## Parameters

    * `reason` - The reason for termination
    * `state` - The current adapter state
  """
  @callback terminate(reason :: term(), state :: term()) :: term()

  @doc """
  Executes a Graph operation through the adapter.

  This function dispatches an operation to the adapter's implementation,
  optionally passing through a pipeline of plugs first.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `operation` - The operation to perform, either `{:query, path, params}` or `{:action, path, params}`
    * `context` - Optional custom context for the operation
    * `timeout` - Optional timeout in milliseconds
    
  ## Returns

    * `{:ok, result}` - Operation succeeded with the given result
    * `{:error, reason}` - Operation failed with the given reason
  """
  @spec execute(
          module() | pid(),
          operation(),
          Context.t() | nil,
          timeout :: non_neg_integer() | :infinity
        ) ::
          {:ok, term()} | {:error, term()}
  def execute(adapter, operation, context \\ nil, timeout \\ 5000) do
    # If no context is provided, create a new one
    context = context || Context.new()

    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter

    # Send operation to adapter process
    try do
      GenServer.call(adapter_pid, {:operation, operation, context}, timeout)
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}

      :exit, reason ->
        {:error, {:server_error, reason}}
    end
  end

  @doc """
  Starts an adapter as a linked process.

  ## Options

    * `:adapter` - The adapter module to use (required)
    * `:name` - Optional name to register the process
    * `:plugs` - Optional list of plugs to apply
    * Other options are passed to the adapter's `init/1` callback
    
  ## Returns

    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    name = Keyword.get(opts, :name)

    # Start the adapter GenServer
    GenServer.start_link(GraphOS.Adapter.Server, {adapter, opts}, name: name)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour GraphOS.Adapter.GraphAdapter

      # Default implementations

      @impl true
      def terminate(_reason, _state), do: :ok

      # Make callbacks overridable
      defoverridable terminate: 2
    end
  end
end
