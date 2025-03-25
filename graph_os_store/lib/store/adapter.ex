defmodule GraphOS.Store.Adapter do
  @moduledoc """
  Defines the interface for store adapters.
  """

  @callback init(atom(), Keyword.t()) :: {:ok, atom()} | {:error, term()}
  @callback register_schema(atom(), map()) :: :ok | {:error, term()}
  @callback insert(module(), map()) :: {:ok, map()} | {:error, term()}
  @callback update(module(), map()) :: {:ok, map()} | {:error, term()}
  @callback delete(module(), binary()) :: :ok | {:error, term()}
  @callback get(module(), binary()) :: {:ok, map()} | {:error, term()}
  @callback all(module(), map(), Keyword.t()) :: {:ok, list(term())} | {:error, term()}

  @optional_callbacks [traverse: 2]
  @callback traverse(atom(), tuple() | list()) :: {:ok, term()} | {:error, term()}
end
