defmodule GraphOS.Access do
  @moduledoc """
  Access control for GraphOS.

  Provides functions for creating and managing policies, actors, scopes and permissions.
  """

  use Boundary, deps: [GraphOS.Store, GraphOS.Entity], exports: [Policy, Actor, Scope, Permission]

  alias GraphOS.Access.{Policy, Actor, Scope, Permission}
  alias GraphOS.Store

  @doc """
  Creates a new policy graph.

  ## Examples

      iex> GraphOS.Access.create_policy("main_policy")
      {:ok, %GraphOS.Entity.Graph{id: "policy_id", name: "main_policy"}}
  """
  @spec create_policy(String.t()) :: {:ok, GraphOS.Entity.Graph.t()} | {:error, any()}
  def create_policy(name) do
    policy = GraphOS.Entity.Graph.new(%{name: name})
    Store.insert(Policy, policy)
  end

  @doc """
  Creates a new actor in the specified policy.

  ## Examples

      iex> GraphOS.Access.create_actor("policy_id", %{id: "user_1", name: "John Doe"})
      {:ok, %GraphOS.Entity.Node{id: "user_1", data: %{name: "John Doe"}}}
  """
  @spec create_actor(GraphOS.Entity.id(), map()) :: {:ok, GraphOS.Entity.Node.t()} | {:error, any()}
  def create_actor(policy_id, attrs) do
    actor = GraphOS.Entity.Node.new(%{
      graph_id: policy_id,
      id: Map.get(attrs, :id, UUIDv7.generate()),
      data: attrs
    })

    Store.insert(Actor, actor)
  end

  @doc """
  Creates a new scope in the specified policy.

  ## Examples

      iex> GraphOS.Access.create_scope("policy_id", %{id: "resource_1"})
      {:ok, %GraphOS.Entity.Node{id: "resource_1"}}
  """
  @spec create_scope(GraphOS.Entity.id(), map()) :: {:ok, GraphOS.Entity.Node.t()} | {:error, any()}
  def create_scope(policy_id, attrs) do
    scope = GraphOS.Entity.Node.new(%{
      graph_id: policy_id,
      id: Map.get(attrs, :id, UUIDv7.generate()),
      data: attrs
    })

    Store.insert(Scope, scope)
  end

  @doc """
  Creates a permission edge between a scope and an actor.

  ## Parameters

  - `policy_id` - The ID of the policy
  - `scope_id` - The ID of the scope (source)
  - `actor_id` - The ID of the actor (target)
  - `permissions` - Map of permissions (read, write, execute, destroy)

  ## Examples

      iex> GraphOS.Access.grant_permission("policy_id", "resource_1", "user_1", %{read: true, write: true})
      {:ok, %GraphOS.Entity.Edge{source: "resource_1", target: "user_1", data: %{read: true, write: true}}}
  """
  @spec grant_permission(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id(), map()) ::
    {:ok, GraphOS.Entity.Edge.t()} | {:error, any()}
  def grant_permission(policy_id, scope_id, actor_id, permissions) do
    edge = GraphOS.Entity.Edge.new(%{
      graph_id: policy_id,
      source: scope_id,
      target: actor_id,
      data: permissions
    })

    Store.insert(Permission, edge)
  end

  @doc """
  Checks if an actor has a specific permission on a scope.

  ## Examples

      iex> GraphOS.Access.has_permission?("resource_1", "user_1", :read)
      true
  """
  @spec has_permission?(GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_permission?(scope_id, actor_id, permission) when is_atom(permission) do
    case Store.query(Permission, [source: scope_id, target: actor_id]) do
      {:ok, []} -> false
      {:ok, edges} ->
        # Check if any edge grants the requested permission
        Enum.any?(edges, fn edge ->
          Map.get(edge.data, permission, false)
        end)
      {:error, _} -> false
    end
  end

  @doc """
  Lists all permissions for a specific actor.

  ## Examples

      iex> GraphOS.Access.list_actor_permissions("user_1")
      {:ok, [%{scope_id: "resource_1", permissions: %{read: true, write: false}}]}
  """
  @spec list_actor_permissions(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_actor_permissions(actor_id) do
    case Store.query(Permission, [target: actor_id]) do
      {:ok, edges} ->
        result = Enum.map(edges, fn edge ->
          %{
            scope_id: edge.source,
            permissions: edge.data
          }
        end)
        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all permissions on a specific scope.

  ## Examples

      iex> GraphOS.Access.list_scope_permissions("resource_1")
      {:ok, [%{actor_id: "user_1", permissions: %{read: true, write: false}}]}
  """
  @spec list_scope_permissions(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_scope_permissions(scope_id) do
    case Store.query(Permission, [source: scope_id]) do
      {:ok, edges} ->
        result = Enum.map(edges, fn edge ->
          %{
            actor_id: edge.target,
            permissions: edge.data
          }
        end)
        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end
