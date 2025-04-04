defmodule GraphOS.Access.Permission do
  use GraphOS.Entity.Edge,
    graph: GraphOS.Access.Policy,
    # Only allow scopes as sources
    source: [include: [GraphOS.Access.Scope]],
    # Allow actors or groups as targets
    target: [include: [GraphOS.Access.Actor, GraphOS.Access.Group]]

  @type types :: :read | :write | :execute | :destroy
  @types [:read, :write, :execute, :destroy]

  defguard is_type(type) when type in @types

  def data_schema do
    [
      %{name: :read, type: :boolean, default: false},
      %{name: :write, type: :boolean, default: false},
      %{name: :execute, type: :boolean, default: false},
      %{name: :destroy, type: :boolean, default: false}
    ]
  end

  @doc """
  Updates permission settings for an existing permission edge.

  ## Examples

      iex> GraphOS.Access.Permission.update("permission_id", %{write: true})
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def update(permission_id, permissions) do
    with {:ok, permission} <- GraphOS.Store.get(__MODULE__, permission_id),
         updated_data = Map.merge(permission.data, permissions),
         updated_permission = %{permission | data: updated_data} do
      GraphOS.Store.update(__MODULE__, updated_permission)
    end
  end

  @doc """
  Revokes all permissions between a scope and an actor by deleting the permission edge.

  ## Examples

      iex> GraphOS.Access.Permission.revoke("permission_id")
      :ok
  """
  def revoke(permission_id) do
    GraphOS.Store.delete(__MODULE__, permission_id)
  end

  @doc """
  Finds permission edges between a scope and an actor or group.

  ## Examples

      iex> GraphOS.Access.Permission.find_between("scope_id", "actor_id")
      {:ok, [%GraphOS.Entity.Edge{}]}
  """
  def find_between(scope_id, target_id) do
    GraphOS.Store.all(__MODULE__, %{source: scope_id, target: target_id})
  end

  @doc """
  Checks if a permission edge grants a specific permission.

  ## Examples

      iex> permission = %GraphOS.Entity.Edge{data: %{read: true, write: false}}
      iex> GraphOS.Access.Permission.grants?(permission, :read)
      true
      iex> GraphOS.Access.Permission.grants?(permission, :write)
      false
  """
  def grants?(permission, permission_type) when is_atom(permission_type) do
    Map.get(permission.data, permission_type, false)
  end

  @doc """
  Creates a new permission edge between a scope and an actor or group.

  ## Examples

      iex> GraphOS.Access.Permission.grant("policy_id", "scope_id", "user_1", %{read: true})
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def grant(policy_id, scope_id, target_id, permissions) do
    GraphOS.Access.grant_permission(policy_id, scope_id, target_id, permissions)
  end
end
