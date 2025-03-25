defmodule GraphOS.Access.Actor do
  use GraphOS.Entity.Node,
    graph: GraphOS.Access.Policy

  def data_schema do
    [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, required: true},
    ]
  end

  @doc """
  Lists all permissions granted to this actor.

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
end
