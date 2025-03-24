defmodule GraphOS.Protocol.Adapter do
  @moduledoc """
  Core adapter functionality for protocol implementations.

  This module integrates with the GraphOS.Store.StoreAdapter system to provide protocol-specific
  adapters for different communication protocols. It serves as the foundation for
  all protocol implementations in the GraphOS.Protocol namespace.

  ## Protocol Implementations

  - `GraphOS.Protocol.JSONRPC`: JSON-RPC 2.0 protocol adapter
  - `GraphOS.Protocol.GRPC`: gRPC protocol adapter
  - `GraphOS.Protocol.MCP`: Model Context Protocol adapter

  ## Integration with GraphOS.Store.StoreAdapter

  Protocol adapters are built on top of the GraphOS.Store.StoreAdapter system, which provides
  core functionality for store operations, access control, and query processing.
  Protocol adapters extend this system with protocol-specific behaviors.
  """

  alias GraphOS.Store.StoreAdapter
  alias GraphOS.Store.Transaction
  alias GraphOS.Adapter.Context

  @doc """
  Starts a protocol adapter as a linked process.

  This is a convenience function that delegates to GraphOS.Store.StoreAdapter.init/2.

  ## Parameters

    * `adapter_module` - The protocol adapter module
    * `opts` - Adapter options

  ## Returns

    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(module(), Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(adapter_module, opts) do
    StoreAdapter.init(adapter_module, Keyword.put(opts, :adapter, adapter_module))
  end

  @doc """
  Executes an operation through a protocol adapter.

  This is a convenience function that delegates to GraphOS.Store.StoreAdapter.execute/2.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `operation` - The operation to perform
    * `context` - Optional custom context for the operation
    * `timeout` - Optional timeout in milliseconds

  ## Returns

    * `{:ok, result}` - Operation succeeded with the given result
    * `{:error, reason}` - Operation failed with the given reason
  """
  @spec execute(
          module() | pid(),
          Transaction.t(),
          Context.t() | nil,
          timeout :: non_neg_integer() | :infinity
        ) ::
          {:ok, term()} | {:error, term()}
  def execute(adapter, operation, context \\ nil, timeout \\ 5000) do
    StoreAdapter.execute(operation, adapter: adapter, context: context, timeout: timeout)
  end

  @doc """
  Macro for implementing protocol adapters.

  This macro sets up the necessary behavior implementations and default functions
  for protocol adapters.

  ## Example

  ```elixir
  defmodule MyProtocolAdapter do
    use GraphOS.Protocol.Adapter

    @impl true
    def init(opts) do
      # Initialize adapter state
      {:ok, %{config: opts}}
    end

    @impl true
    def handle_operation(operation, context, state) do
      # Handle a Graph operation
      # ...
    end
  end
  ```
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour GraphOS.Store.Protocol

      # Import common functionality
      import GraphOS.Protocol.Adapter, only: [execute: 3, execute: 4]

      # Define start_link function
      @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()}
      def start_link(opts) do
        GraphOS.Protocol.Adapter.start_link(__MODULE__, opts)
      end

      # Default implementations
      @impl GraphOS.Store.Protocol
      def init(opts \\ []), do: {:ok, opts}

      @impl GraphOS.Store.Protocol
      def execute(operation, opts \\ []), do: {:ok, operation}

      @impl GraphOS.Store.Protocol
      def close, do: :ok

      defoverridable init: 1, execute: 2, close: 0
    end
  end
end
