defmodule GraphOS.Access.Group do
  @moduledoc """
  Represents a group of actors in the access control system.

  Groups allow for simplified permission management by granting permissions
  to a collection of actors at once.
  """

  use GraphOS.Entity.Node,
    graph: GraphOS.Access.Policy

  def data_schema do
    [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, required: true},
      %{name: :description, type: :string}
    ]
  end

  @doc """
  Lists all permissions granted to this group.

  ## Examples

      iex> group_id = "admins"
      iex> GraphOS.Access.Group.permissions(group_id)
      {:ok, [%{scope_id: "resource_1", permissions: %{read: true, write: true}}]}
  """
  def permissions(group_id) do
    GraphOS.Access.list_direct_permissions(group_id)
  end

  @doc """
  Lists all members (actors) of this group.

  ## Examples

      iex> group_id = "admins"
      iex> GraphOS.Access.Group.members(group_id)
      {:ok, [%{actor_id: "user_1", joined_at: ~U[2023-01-01 00:00:00Z]}]}
  """
  def members(group_id) do
    case GraphOS.Store.all(GraphOS.Access.Membership, %{target: group_id}) do
      {:ok, memberships} ->
        result =
          Enum.map(memberships, fn edge ->
            %{
              actor_id: edge.source,
              joined_at: Map.get(edge.data, :joined_at)
            }
          end)

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds a member to the group.

  ## Examples

      iex> policy_id = "policy_1"
      iex> group_id = "admins"
      iex> actor_id = "user_1"
      iex> GraphOS.Access.Group.add_member(policy_id, group_id, actor_id)
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def add_member(policy_id, group_id, actor_id) do
    GraphOS.Access.add_to_group(policy_id, actor_id, group_id)
  end

  @doc """
  Removes a member from the group.

  ## Examples

      iex> group_id = "admins"
      iex> actor_id = "user_1"
      iex> GraphOS.Access.Group.remove_member(group_id, actor_id)
      :ok
  """
  def remove_member(group_id, actor_id) do
    case GraphOS.Store.all(GraphOS.Access.Membership, %{source: actor_id, target: group_id}) do
      {:ok, [membership | _]} ->
        GraphOS.Store.delete(GraphOS.Access.Membership, membership.id)

      {:ok, []} ->
        {:error, :not_a_member}

      error ->
        error
    end
  end

  @doc """
  Checks if an actor is a member of this group.

  ## Examples

      iex> group_id = "admins"
      iex> actor_id = "user_1"
      iex> GraphOS.Access.Group.has_member?(group_id, actor_id)
      true
  """
  def has_member?(group_id, actor_id) do
    case GraphOS.Store.all(GraphOS.Access.Membership, %{source: actor_id, target: group_id}) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end

  @doc """
  Checks if this group has a specific permission on a scope.

  ## Examples

      iex> group_id = "admins"
      iex> scope_id = "resource_1"
      iex> GraphOS.Access.Group.has_permission?(group_id, scope_id, :read)
      true
  """
  def has_permission?(group_id, scope_id, permission) do
    GraphOS.Access.has_direct_permission?(scope_id, group_id, permission)
  end
end
