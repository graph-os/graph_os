defmodule GraphOS.GraphContext.Transaction do
  @moduledoc """
  A transaction for the graph.
  """

  alias GraphOS.GraphContext.Operation
  alias GraphOS.GraphContext.Store

  defstruct [:store, :operations]

  @type t() :: %__MODULE__{
    store: Store.t(),
    operations: [Operation.t()]
  }

  @type result() :: {:ok, map()}| {:error, term()}

  @spec new(Store.t()) :: t()
  def new(store) do
    %__MODULE__{store: store, operations: []}
  end

  @spec add(t(), Operation.t()) :: t()
  def add(%__MODULE__{} = transaction, %Operation{} = operation) do
    %{transaction | operations: [operation | transaction.operations]}
  end

  @spec commit(t()) :: result()
  def commit(%__MODULE__{} = transaction) do
    transaction.store.execute(transaction)
  end
end
