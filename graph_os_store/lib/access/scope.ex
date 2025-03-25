defmodule GraphOS.Access.Scope do
  use GraphOS.Entity.Node,
    graph: GraphOS.Access.Policy

  def data_schema do
    [
      %{name: :id, type: :string, required: true}
    ]
  end

  @doc """
  Lists all permissions granted on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> GraphOS.Access.Scope.permissions(scope_id)
      {:ok, [%{actor_id: "user_1", permissions: %{read: true, write: false}}]}
  """
  def permissions(scope_id) do
    GraphOS.Access.list_scope_permissions(scope_id)
  end

  @doc """
  Grants a permission to an actor on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> actor_id = "user_1"
      iex> policy_id = "policy_1"
      iex> GraphOS.Access.Scope.grant_to(policy_id, scope_id, actor_id, %{read: true})
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def grant_to(policy_id, scope_id, actor_id, permissions) do
    GraphOS.Access.grant_permission(policy_id, scope_id, actor_id, permissions)
  end

  @doc """
  Checks if a given actor has permission on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> actor_id = "user_1"
      iex> GraphOS.Access.Scope.actor_has_permission?(scope_id, actor_id, :read)
      true
  """
  def actor_has_permission?(scope_id, actor_id, permission) do
    GraphOS.Access.has_permission?(scope_id, actor_id, permission)
  end
end
