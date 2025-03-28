defmodule GraphOS.Access.Actor do
  @moduledoc """
  Represents an actor (user or service) in the access control system.

  Actors can be granted permissions directly or through group memberships.
  """

  use GraphOS.Entity.Node,
    graph: GraphOS.Access.Policy

  def data_schema do
    [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, required: true},
      %{name: :email, type: :string},
      %{name: :metadata, type: :map, default: %{}}
    ]
  end

  @doc """
  Lists all permissions granted to this actor, including those inherited from groups.

  ## Examples

      iex> actor_id = "user_1"
      iex> GraphOS.Access.Actor.permissions(actor_id)
      {:ok, [%{scope_id: "resource_1", permissions: %{read: true, write: false}}]}
  """
  def permissions(actor_id) do
    GraphOS.Access.list_actor_permissions(actor_id)
  end

  @doc """
  Checks if the actor has a specific permission on a scope.

  ## Examples

      iex> actor_id = "user_1"
      iex> scope_id = "resource_1"
      iex> GraphOS.Access.Actor.has_permission?(actor_id, scope_id, :read)
      true
  """
  def has_permission?(actor_id, scope_id, permission) do
    GraphOS.Access.has_permission?(scope_id, actor_id, permission)
  end

  @doc """
  Lists all groups the actor is a member of.

  ## Examples

      iex> actor_id = "user_1"
      iex> GraphOS.Access.Actor.groups(actor_id)
      {:ok, [%{group_id: "admins", joined_at: ~U[2023-01-01 00:00:00Z]}]}
  """
  def groups(actor_id) do
    case GraphOS.Store.all(GraphOS.Access.Membership, %{source: actor_id}) do
      {:ok, memberships} ->
        result =
          Enum.map(memberships, fn edge ->
            %{
              group_id: edge.target,
              joined_at: Map.get(edge.data, :joined_at)
            }
          end)

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if the actor is a member of a specific group.

  ## Examples

      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Actor.member_of?(actor_id, group_id)
      true
  """
  def member_of?(actor_id, group_id) do
    GraphOS.Access.Group.has_member?(group_id, actor_id)
  end

  @doc """
  Joins a group.

  ## Examples

      iex> policy_id = "policy_1"
      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Actor.join_group(policy_id, actor_id, group_id)
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def join_group(policy_id, actor_id, group_id) do
    GraphOS.Access.add_to_group(policy_id, actor_id, group_id)
  end

  @doc """
  Leaves a group.

  ## Examples

      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Actor.leave_group(actor_id, group_id)
      :ok
  """
  def leave_group(actor_id, group_id) do
    GraphOS.Access.Group.remove_member(group_id, actor_id)
  end

  @doc """
  Checks if the actor is authorized to perform an operation on a node.

  ## Examples

      iex> actor_id = "user_1"
      iex> node_id = "document_1"
      iex> GraphOS.Access.Actor.authorized?(actor_id, :read, node_id)
      true
  """
  def authorized?(actor_id, operation, node_id) do
    GraphOS.Access.authorize(actor_id, operation, node_id)
  end
end
