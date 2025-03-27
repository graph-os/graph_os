defmodule GraphOS.Access.Membership do
  @moduledoc """
  Represents a membership relationship between an actor and a group.

  Membership edges connect actors (source) to groups (target) and allow
  actors to inherit permissions granted to groups.
  """

  use GraphOS.Entity.Edge,
    graph: GraphOS.Access.Policy,
    source: [include: [GraphOS.Access.Actor]], # Only allow actors as sources
    target: [include: [GraphOS.Access.Group]]  # Only allow groups as targets

  def data_schema do
    [
      %{name: :joined_at, type: :datetime, required: true},
      %{name: :metadata, type: :map, default: %{}}
    ]
  end

  @doc """
  Find all memberships for an actor.

  ## Examples

      iex> actor_id = "user_1"
      iex> GraphOS.Access.Membership.find_by_actor(actor_id)
      {:ok, [%GraphOS.Entity.Edge{source: "user_1", target: "admins"}]}
  """
  def find_by_actor(actor_id) do
    GraphOS.Store.all(__MODULE__, %{source: actor_id})
  end

  @doc """
  Find all memberships for a group.

  ## Examples

      iex> group_id = "admins"
      iex> GraphOS.Access.Membership.find_by_group(group_id)
      {:ok, [%GraphOS.Entity.Edge{source: "user_1", target: "admins"}]}
  """
  def find_by_group(group_id) do
    GraphOS.Store.all(__MODULE__, %{target: group_id})
  end

  @doc """
  Check if a membership exists between an actor and a group.

  ## Examples

      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Membership.exists?(actor_id, group_id)
      true
  """
  def exists?(actor_id, group_id) do
    case GraphOS.Store.all(__MODULE__, %{source: actor_id, target: group_id}) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end

  @doc """
  Create a new membership between an actor and a group.

  ## Examples

      iex> policy_id = "policy_1"
      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Membership.create(policy_id, actor_id, group_id)
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def create(policy_id, actor_id, group_id) do
    GraphOS.Access.add_to_group(policy_id, actor_id, group_id)
  end

  @doc """
  Remove a membership between an actor and a group.

  ## Examples

      iex> actor_id = "user_1"
      iex> group_id = "admins"
      iex> GraphOS.Access.Membership.remove(actor_id, group_id)
      :ok
  """
  def remove(actor_id, group_id) do
    case GraphOS.Store.all(__MODULE__, %{source: actor_id, target: group_id}) do
      {:ok, [membership | _]} ->
        GraphOS.Store.delete(__MODULE__, membership.id)
      {:ok, []} -> {:error, :not_a_member}
      error -> error
    end
  end
end
