defmodule GraphOS.Graph.Adapter do
  @moduledoc """
  Defines the behavior for GraphOS Graph adapters.
  
  IMPORTANT: This module is deprecated and will be removed in a future version.
  Please use `GraphOS.Adapter.GraphAdapter` instead.
  
  Graph adapters are protocol-specific implementations that translate between
  the GraphOS Graph API and various communication protocols. They allow the Graph
  to be accessed through different interfaces while maintaining consistent semantics.
  """
  
  @doc """
  This module is deprecated and delegates to the new `GraphOS.Adapter.GraphAdapter` module.
  Please update your code to use the new module directly.
  """
  
  @doc """
  Executes a Graph operation through the adapter.
  Delegates to `GraphOS.Adapter.GraphAdapter.execute/4`.
  """
  @spec execute(module() | pid(), any(), any() | nil, timeout :: non_neg_integer() | :infinity) ::
          {:ok, term()} | {:error, term()}
  def execute(adapter, operation, context \\ nil, timeout \\ 5000) do
    require Logger
    Logger.warning("GraphOS.Graph.Adapter is deprecated, use GraphOS.Adapter.GraphAdapter instead")
    # Temporary stub implementation to avoid circular dependencies during refactoring
    {:error, :deprecated}
  end
  
  @doc """
  Starts an adapter as a linked process.
  Delegates to `GraphOS.Adapter.GraphAdapter.start_link/1`.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    require Logger
    Logger.warning("GraphOS.Graph.Adapter is deprecated, use GraphOS.Adapter.GraphAdapter instead")
    # Temporary stub implementation to avoid circular dependencies during refactoring
    {:error, :deprecated}
  end
  
  @doc false
  defmacro __using__(_opts) do
    quote do
      require Logger
      Logger.warning("GraphOS.Graph.Adapter is deprecated, use GraphOS.Adapter.GraphAdapter instead")
      # Temporary stub implementation to avoid circular dependencies during refactoring
      @behaviour unquote(__MODULE__)
      
      @impl true
      def terminate(_reason, _state), do: :ok
      
      defoverridable terminate: 2
    end
  end

  # Define callback stubs to avoid compiler errors during refactoring
  @callback init(opts :: term()) :: {:ok, state :: term()} | {:error, reason :: term()}
  @callback handle_operation(operation :: term(), context :: term(), state :: term()) :: term()
  @callback terminate(reason :: term(), state :: term()) :: term()
end