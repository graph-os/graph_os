defmodule GraphOS.Access.OperationGuard do
  @moduledoc """
  Provides functionality to automatically check access control permissions for operations.

  This module can be used to guard operations (insert/update/delete) based on the actor's permissions.
  It is designed to be used as a hook in GraphOS.Store operations.
  """

  alias GraphOS.Entity.{Node, Edge, Graph}
  alias GraphOS.Access

  @doc """
  Checks if an actor is authorized to perform an operation on an entity.

  ## Parameters

  - `actor_id` - The ID of the actor requesting the operation
  - `operation` - The operation type (:read, :write, :execute, :destroy)
  - `entity` - The entity to check permissions on
  - `opts` - Additional options

  ## Returns

  - `{:ok, entity}` if authorized
  - `{:error, reason}` if not authorized
  """
  @spec check_permission(String.t(), atom(), struct(), keyword()) :: {:ok, struct()} | {:error, String.t()}
  def check_permission(actor_id, operation, entity, _opts \\ []) do
    case is_authorized?(actor_id, operation, entity) do
      true -> {:ok, entity}
      false -> {:error, "Access denied: Actor #{actor_id} is not authorized for #{operation} on #{entity.__struct__}"}
    end
  end

  @doc """
  Determines if an actor is authorized to perform an operation on an entity.

  ## Examples

      iex> actor_id = "user_1"
      iex> node = %GraphOS.Entity.Node{id: "document_1"}
      iex> GraphOS.Access.OperationGuard.is_authorized?(actor_id, :read, node)
      true
  """
  @spec is_authorized?(String.t(), atom(), struct()) :: boolean()
  def is_authorized?(actor_id, operation, %Node{} = node) do
    Access.authorize(actor_id, operation, node.id)
  end

  def is_authorized?(actor_id, operation, %Edge{} = edge) do
    # For edges, check permissions on both source and target
    Access.authorize(actor_id, operation, edge.source) and
      Access.authorize(actor_id, operation, edge.target)
  end

  def is_authorized?(actor_id, operation, %Graph{} = graph) do
    # For graphs, check permissions on the graph itself
    Access.authorize(actor_id, operation, graph.id)
  end

  def is_authorized?(_actor_id, _operation, _entity) do
    # Default to false for unknown entity types
    false
  end

  @doc """
  Wraps an operation function with permission checking.

  ## Examples

      iex> operation_fn = fn entity, opts -> {:ok, entity} end
      iex> guarded_operation = GraphOS.Access.OperationGuard.guard(operation_fn, :write)
      iex> guarded_operation.(%{id: "document_1"}, actor_id: "user_1")
      {:ok, %{id: "document_1"}}
  """
  @spec guard(function(), atom()) :: function()
  def guard(operation_fn, operation_type) when is_function(operation_fn, 2) and is_atom(operation_type) do
    fn entity, opts ->
      actor_id = Keyword.get(opts, :actor_id)

      if actor_id do
        with {:ok, entity} <- check_permission(actor_id, operation_type, entity, opts) do
          operation_fn.(entity, opts)
        end
      else
        # If no actor_id is provided, skip permission check
        operation_fn.(entity, opts)
      end
    end
  end

  @doc """
  Helper to create a before_insert hook that checks write permissions.

  ## Examples

      defmodule MyEntity do
        def before_insert(entity, opts) do
          GraphOS.Access.OperationGuard.before_insert(entity, opts)
        end
      end
  """
  @spec before_insert(struct(), keyword()) :: {:ok, struct()} | {:error, String.t()}
  def before_insert(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    if actor_id, do: check_permission(actor_id, :write, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_update hook that checks write permissions.
  """
  @spec before_update(struct(), keyword()) :: {:ok, struct()} | {:error, String.t()}
  def before_update(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    if actor_id, do: check_permission(actor_id, :write, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_delete hook that checks destroy permissions.
  """
  @spec before_delete(struct(), keyword()) :: {:ok, struct()} | {:error, String.t()}
  def before_delete(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    if actor_id, do: check_permission(actor_id, :destroy, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_read hook that checks read permissions.
  """
  @spec before_read(struct(), keyword()) :: {:ok, struct()} | {:error, String.t()}
  def before_read(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    if actor_id, do: check_permission(actor_id, :read, entity, opts), else: {:ok, entity}
  end
end
