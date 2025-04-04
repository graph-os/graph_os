defmodule GraphOS.Access.Scope do
  @moduledoc """
  Represents a scope (protected resource or collection) in the access control system.

  Scopes can be bound to any node type and control how actors interact with those nodes.
  """

  use GraphOS.Entity.Node,
    graph: GraphOS.Access.Policy

  def data_schema do
    [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, required: true},
      %{name: :description, type: :string},
      %{name: :metadata, type: :map, default: %{}}
    ]
  end

  @doc """
  Lists all permissions granted on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> GraphOS.Access.Scope.permissions(scope_id)
      {:ok, [%{target_id: "user_1", target_type: "actor", permissions: %{read: true, write: false}}]}
  """
  def permissions(scope_id) do
    GraphOS.Access.list_scope_permissions(scope_id)
  end

  @doc """
  Grants a permission to an actor or group on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> target_id = "user_1" # or could be a group_id
      iex> policy_id = "policy_1"
      iex> GraphOS.Access.Scope.grant_to(policy_id, scope_id, target_id, %{read: true})
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def grant_to(policy_id, scope_id, target_id, permissions) do
    GraphOS.Access.grant_permission(policy_id, scope_id, target_id, permissions)
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

  @doc """
  Binds this scope to a node, establishing protection for that node.

  ## Examples

      iex> policy_id = "policy_1"
      iex> scope_id = "api_keys_scope"
      iex> node_id = "key_123"
      iex> GraphOS.Access.Scope.bind_to_node(policy_id, scope_id, node_id)
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def bind_to_node(policy_id, scope_id, node_id) do
    GraphOS.Access.bind_scope_to_node(policy_id, scope_id, node_id)
  end

  @doc """
  Lists all nodes that are bound to this scope.

  ## Examples

      iex> scope_id = "api_keys_scope"
      iex> GraphOS.Access.Scope.bound_nodes(scope_id)
      {:ok, [%{node_id: "key_123", bound_at: ~U[2023-01-01 00:00:00Z]}]}
  """
  def bound_nodes(scope_id) do
    GraphOS.Access.list_scope_nodes(scope_id)
  end

  @doc """
  Revokes all permissions for an actor or group on this scope.

  ## Examples

      iex> scope_id = "resource_1"
      iex> target_id = "user_1" # or could be a group_id
      iex> GraphOS.Access.Scope.revoke_from(scope_id, target_id)
      :ok
  """
  def revoke_from(scope_id, target_id) do
    case GraphOS.Store.all(GraphOS.Access.Permission, %{source: scope_id, target: target_id}) do
      {:ok, permissions} when is_list(permissions) and length(permissions) > 0 ->
        results =
          Enum.map(permissions, fn perm ->
            GraphOS.Store.delete(GraphOS.Access.Permission, perm.id)
          end)

        # If any deletion failed, return an error
        if Enum.any?(results, fn r -> r != :ok end) do
          {:error, :deletion_failed}
        else
          :ok
        end

      {:ok, []} ->
        {:error, :no_permissions_found}

      error ->
        error
    end
  end
end
