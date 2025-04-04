defmodule GraphOS.Store.Adapter do
  @moduledoc """
  Defines the interface for store adapters.

  Adapters implementing this behaviour are expected to be GenServers
  started via `GraphOS.Store.start_link/1`.
  """

  # init/2 callback removed - adapter lifecycle managed by GraphOS.Store.start_link

  @doc """
  Callback executed when registering a schema for a specific store instance.
  """
  @callback register_schema(store_ref :: term(), schema :: map()) :: :ok | {:error, term()}

  @doc """
  Callback executed when inserting an entity into a specific store instance.
  Expected to return `{:ok, struct()}` with the persisted entity (including metadata).
  """
  @callback insert(store_ref :: term(), module(), map()) :: {:ok, struct()} | {:error, term()}

  @doc """
  Callback executed when updating an entity in a specific store instance.
  Expected to return `{:ok, struct()}` with the updated entity (including metadata).
  """
  @callback update(store_ref :: term(), module(), map()) :: {:ok, struct()} | {:error, term()}

  @doc """
  Callback executed when deleting an entity from a specific store instance.
  """
  @callback delete(store_ref :: term(), module(), id :: binary()) :: :ok | {:error, term()}

  @doc """
  Callback executed when retrieving an entity from a specific store instance.
  Expected to return `{:ok, struct()}` with the found entity (including metadata).
  """
  @callback get(store_ref :: term(), module(), id :: binary()) :: {:ok, struct()} | {:error, :not_found | :deleted | term()}

  @doc """
  Callback executed when retrieving all entities from a specific store instance.
  Expected to return `{:ok, list(struct())}` with found entities (including metadata).
  """
  @callback all(store_ref :: term(), module(), filter :: map(), opts :: Keyword.t()) :: {:ok, list(struct())} | {:error, term()}

  @doc """
  Callback executed when performing a graph traversal on a specific store instance.
  This callback is optional.
  """
  @optional_callbacks [traverse: 3]
  @callback traverse(store_ref :: term(), algorithm :: atom(), params :: tuple() | list()) :: {:ok, term()} | {:error, term()}
end
