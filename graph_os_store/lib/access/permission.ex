defmodule GraphOS.Access.Permission do
  use GraphOS.Entity.Edge,
    graph: GraphOS.Access.Policy,
    source: [include: GraphOS.Access.Scope], # Only allow scopes as sources
    target: [include: GraphOS.Access.Actor] # Only allow actors as targets

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
  Finds permission edges between a scope and an actor.

  ## Examples

      iex> GraphOS.Access.Permission.find_between("scope_id", "actor_id")
      {:ok, [%GraphOS.Entity.Edge{}]}
  """
  def find_between(scope_id, actor_id) do
    GraphOS.Store.all(__MODULE__, %{source: scope_id, target: actor_id})
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
end
