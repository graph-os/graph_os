defmodule GraphOS.Graph.Protocol do
  @moduledoc """
  A protocol for graph operations.
  """

  alias GraphOS.Graph.Transaction
  alias GraphOS.Graph.Operation

  @callback init() :: :ok | {:error, term()}
  @callback execute(Transaction.t()) :: Transaction.result()
  @callback handle(Operation.message()) :: :ok | {:error, term()}
  @callback close() :: :ok | {:error, term()}
end
