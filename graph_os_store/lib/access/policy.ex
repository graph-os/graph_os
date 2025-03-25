defmodule GraphOS.Access.Policy do
  use GraphOS.Entity.Graph

  alias GraphOS.Store
  alias GraphOS.Access.{Actor, Scope, Permission}

  @doc """
  Creates a new policy with the given name.

  ## Examples

      iex> GraphOS.Access.Policy.create("main_policy")
      {:ok, %GraphOS.Entity.Graph{name: "main_policy"}}
  """
  def create(name) do
    GraphOS.Access.create_policy(name)
  end

  @doc """
  Lists all actors in the policy.

  ## Examples

      iex> GraphOS.Access.Policy.list_actors("policy_id")
      {:ok, [%GraphOS.Entity.Node{}]}
  """
  def list_actors(policy_id) do
    Store.query(Actor, [graph_id: policy_id])
  end

  @doc """
  Lists all scopes in the policy.

  ## Examples

      iex> GraphOS.Access.Policy.list_scopes("policy_id")
      {:ok, [%GraphOS.Entity.Node{}]}
  """
  def list_scopes(policy_id) do
    Store.query(Scope, [graph_id: policy_id])
  end

  @doc """
  Lists all permissions in the policy.

  ## Examples

      iex> GraphOS.Access.Policy.list_permissions("policy_id")
      {:ok, [%GraphOS.Entity.Edge{}]}
  """
  def list_permissions(policy_id) do
    Store.query(Permission, [graph_id: policy_id])
  end

  @doc """
  Adds a new actor to the policy.

  ## Examples

      iex> GraphOS.Access.Policy.add_actor("policy_id", %{id: "user_1", name: "John Doe"})
      {:ok, %GraphOS.Entity.Node{}}
  """
  def add_actor(policy_id, attrs) do
    GraphOS.Access.create_actor(policy_id, attrs)
  end

  @doc """
  Adds a new scope to the policy.

  ## Examples

      iex> GraphOS.Access.Policy.add_scope("policy_id", %{id: "resource_1"})
      {:ok, %GraphOS.Entity.Node{}}
  """
  def add_scope(policy_id, attrs) do
    GraphOS.Access.create_scope(policy_id, attrs)
  end

  @doc """
  Creates a permission edge between a scope and an actor.

  ## Examples

      iex> GraphOS.Access.Policy.grant_permission("policy_id", "resource_1", "user_1", %{read: true})
      {:ok, %GraphOS.Entity.Edge{}}
  """
  def grant_permission(policy_id, scope_id, actor_id, permissions) do
    GraphOS.Access.grant_permission(policy_id, scope_id, actor_id, permissions)
  end

  @doc """
  Checks if an actor has a specific permission on a scope in this policy.

  ## Examples

      iex> GraphOS.Access.Policy.verify_permission?("resource_1", "user_1", :read)
      true
  """
  def verify_permission?(scope_id, actor_id, permission) do
    GraphOS.Access.has_permission?(scope_id, actor_id, permission)
  end
end
