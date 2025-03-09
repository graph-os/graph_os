defmodule GraphOS.Graph.Store do
  @moduledoc """
  Context for `GraphOS.Graph` stores.

  ## Storage drivers

  - `GraphOS.Graph.Store.ETS` - An ETS-based store.
  """

  alias GraphOS.Graph.{Transaction, Operation}

  @doc """
  Initialize the store.

  ## Examples

      iex> GraphOS.Graph.Store.init(GraphOS.Graph.Store.ETS)
      :ok
  """
  @spec init(module()) :: :ok | {:error, term()}
  def init(module \\ GraphOS.Graph.Store.ETS) do
    module.init()
  end

  @doc """
  Execute a transaction.
  """
  @spec execute(Transaction.t()) :: Transaction.result()
  def execute(transaction) do
    transaction.store.execute(transaction)
  end

  @doc """
  Rollback a transaction.
  """
  @spec rollback(Transaction.t()) :: :ok | {:error, term()}
  def rollback(transaction) do
    transaction.store.rollback(transaction)
  end

  @doc """
  Handle an operation.
  """
  @spec handle(Operation.message()) :: :ok | {:error, term()}
  def handle(operation) do
    # Here we need a way to determine which store to use
    # This is a simplification - in a real implementation, you might need
    # to determine the store from context or pass it explicitly
    GraphOS.Graph.Store.ETS.handle(operation)
  end

  @doc """
  Close the store.
  """
  @spec close(module()) :: :ok | {:error, term()}
  def close(module \\ GraphOS.Graph.Store.ETS) do
    module.close()
  end
end
