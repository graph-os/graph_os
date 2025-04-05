defmodule GraphOS.Protocol.Adapter do
  @moduledoc """
  Core adapter functionality for protocol implementations.

  This module integrates with the GraphOS.Adapter system to provide protocol-specific
  adapters for different communication protocols. It serves as the foundation for
  all protocol implementations in the GraphOS.Protocol namespace.

  ## Protocol Implementations

  - `GraphOS.Protocol.JSONRPC`: JSON-RPC 2.0 protocol adapter
  - `GraphOS.Protocol.GRPC`: gRPC protocol adapter
  - `GraphOS.Protocol.MCP`: Model Context Protocol adapter

  ## Integration with GraphOS.Adapter

  Protocol adapters are built on top of the GraphOS.Adapter system, which provides
  core functionality for adapter operation, context management, and middleware
  processing. Protocol adapters extend this system with protocol-specific behaviors.
  """

  alias GraphOS.Adapter.GraphAdapter
  alias GraphOS.Adapter.Context

  @doc """
  Starts a protocol adapter as a linked process.

  This is a convenience function that delegates to GraphOS.Adapter.GraphAdapter.start_link/1.

  ## Parameters

    * `adapter_module` - The protocol adapter module
    * `opts` - Adapter options

  ## Returns

    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(module(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(_adapter_module, _opts) do
    # GraphAdapter.start_link(Keyword.put(opts, :adapter, adapter_module))
    # TODO: This delegation is incorrect as GraphAdapter doesn't exist or is inaccessible.
    # Protocol adapters need to handle their own process starting.
    {:error, :not_implemented}
  end

  @doc """
  Executes an operation through a protocol adapter.

  This is a convenience function that delegates to GraphOS.Adapter.GraphAdapter.execute/4.

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
          GraphAdapter.operation(),
          Context.t() | nil,
          timeout :: non_neg_integer() | :infinity
        ) ::
          {:ok, term()} | {:error, term()}
  def execute(_adapter, _operation, _context \\ nil, _timeout \\ 5000) do
    # GraphAdapter.execute(adapter, operation, context, timeout)
    # TODO: This delegation is incorrect as GraphAdapter doesn't exist or is inaccessible.
    # Protocol adapters need to handle their own execution dispatch.
    {:error, :not_implemented}
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
      # Removed: 'use GraphOS.Adapter.GraphAdapter' as it doesn't exist / is incorrect here.
      # Protocol adapters define their own behaviour or use standard GenServer.

      # Import common functionality
      import GraphOS.Protocol.Adapter, only: [execute: 3, execute: 4]

      # Removed automatic start_link definition from macro.
      # Protocol adapters should define their own start_link if needed,
      # likely using GenServer.start_link directly.
    end
  end
end
