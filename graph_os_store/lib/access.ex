defmodule GraphOS.Access do
  @moduledoc """
  Access control for GraphOS.

  Provides functions for creating and managing policies, actors, groups, scopes and permissions.
  Implements a role-based access control system where:

  - Actors: Users or services that need access to resources
  - Groups: Collections of actors for easier permission management
  - Scopes: Resources or collections of resources that need protection
  - Permissions: Rules defining what operations actors can perform on scopes
  """

  use Boundary, deps: [GraphOS.Store, GraphOS.Entity], exports: [Policy, Actor, Group, Membership, Scope, Permission, OperationGuard]

  alias GraphOS.Access.{Policy, Actor, Group, Membership, Scope, Permission}
  alias GraphOS.Store

  @permission_types [:read, :write, :execute, :destroy]

  @doc """
  Allows access to module attributes for testing purposes.
  """
  def instance_variable(name) do
    case name do
      :permission_types -> @permission_types
      _ -> nil
    end
  end

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
  Creates a new group in the specified policy.

  ## Examples

      iex> GraphOS.Access.create_group("policy_id", %{id: "admins", name: "Administrators"})
      {:ok, %GraphOS.Entity.Node{id: "admins", data: %{name: "Administrators"}}}
  """
  @spec create_group(GraphOS.Entity.id(), map()) :: {:ok, GraphOS.Entity.Node.t()} | {:error, any()}
  def create_group(policy_id, attrs) do
    group = GraphOS.Entity.Node.new(%{
      graph_id: policy_id,
      id: Map.get(attrs, :id, UUIDv7.generate()),
      data: attrs
    })

    Store.insert(Group, group)
  end

  @doc """
  Adds an actor to a group by creating a membership edge.

  ## Examples

      iex> GraphOS.Access.add_to_group("policy_id", "user_1", "admins")
      {:ok, %GraphOS.Entity.Edge{source: "user_1", target: "admins"}}
  """
  @spec add_to_group(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
    {:ok, GraphOS.Entity.Edge.t()} | {:error, any()}
  def add_to_group(policy_id, actor_id, group_id) do
    membership = GraphOS.Entity.Edge.new(%{
      graph_id: policy_id,
      source: actor_id,
      target: group_id,
      data: %{joined_at: DateTime.utc_now()}
    })

    Store.insert(Membership, membership)
  end

  @doc """
  Creates a new scope in the specified policy.

  ## Examples

      iex> GraphOS.Access.create_scope("policy_id", %{id: "resource_1", name: "API Keys"})
      {:ok, %GraphOS.Entity.Node{id: "resource_1", data: %{name: "API Keys"}}}
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
  Creates a permission edge between a scope and an actor or group.

  ## Parameters

  - `policy_id` - The ID of the policy
  - `scope_id` - The ID of the scope (source)
  - `target_id` - The ID of the actor or group (target)
  - `permissions` - Map of permissions (read, write, execute, destroy)

  ## Examples

      iex> GraphOS.Access.grant_permission("policy_id", "resource_1", "user_1", %{read: true, write: true})
      {:ok, %GraphOS.Entity.Edge{source: "resource_1", target: "user_1", data: %{read: true, write: true}}}
  """
  @spec grant_permission(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id(), map()) ::
    {:ok, GraphOS.Entity.Edge.t()} | {:error, any()}
  def grant_permission(policy_id, scope_id, target_id, permissions) do
    # Validate permissions map
    validated_permissions = Map.take(permissions, @permission_types)

    edge = GraphOS.Entity.Edge.new(%{
      graph_id: policy_id,
      source: scope_id,
      target: target_id,
      data: validated_permissions
    })

    Store.insert(Permission, edge)
  end

  @doc """
  Checks if an actor has a specific permission on a scope.
  This function also checks group memberships.

  ## Examples

      iex> GraphOS.Access.has_permission?("resource_1", "user_1", :read)
      true
  """
  @spec has_permission?(GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_permission?(scope_id, actor_id, permission) when is_atom(permission) do
    # First check direct permissions
    case has_direct_permission?(scope_id, actor_id, permission) do
      true -> true
      false ->
        # If not, check for group memberships and their permissions
        case Store.all(Membership, %{source: actor_id}) do
          {:ok, memberships} when is_list(memberships) and length(memberships) > 0 ->
            # Get all groups the actor belongs to
            group_ids = Enum.map(memberships, fn edge -> edge.target end)

            # Check if any group has the permission
            Enum.any?(group_ids, fn group_id ->
              has_direct_permission?(scope_id, group_id, permission)
            end)
          _ -> false
        end
    end
  end

  @doc """
  Checks if an actor has a direct permission on a scope, without considering group memberships.
  """
  @spec has_direct_permission?(GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_direct_permission?(scope_id, target_id, permission) when is_atom(permission) do
    case Store.all(Permission, %{source: scope_id, target: target_id}) do
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
  Checks if an actor is authorized to perform an operation on a node.

  ## Parameters

  - `actor_id` - The ID of the actor requesting the operation
  - `operation` - The operation (:read, :write, :execute, :destroy)
  - `node_id` - The ID of the node to operate on

  ## Returns

  - `true` if authorized
  - `false` if not authorized
  """
  @spec authorize(GraphOS.Entity.id(), atom(), GraphOS.Entity.id()) :: boolean()
  def authorize(actor_id, operation, node_id) when operation in @permission_types do
    # Find all scopes that the node belongs to
    case find_scopes_for_node(node_id) do
      {:ok, scope_ids} when is_list(scope_ids) and length(scope_ids) > 0 ->
        # Check if actor has permission for the operation on any of the scopes
        Enum.any?(scope_ids, fn scope_id ->
          has_permission?(scope_id, actor_id, operation)
        end)
      _ -> false
    end
  end

  @doc """
  Finds all scopes that a node belongs to.
  """
  @spec find_scopes_for_node(GraphOS.Entity.id()) :: {:ok, [GraphOS.Entity.id()]} | {:error, any()}
  def find_scopes_for_node(node_id) do
    # Look for edges connecting scopes to this node
    case Store.all(GraphOS.Entity.Edge, %{target: node_id}) do
      {:ok, edges} ->
        # Filter for edges coming from Scope nodes
        {:ok, scope_edges} =
          edges
          |> Enum.filter(fn edge ->
            case Store.get(Scope, edge.source) do
              {:ok, _} -> true
              _ -> false
            end
          end)

        scope_ids = Enum.map(scope_edges, fn edge -> edge.source end)
        {:ok, scope_ids}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Binds a scope to a node, establishing that the node is protected by the scope.

  ## Examples

      iex> GraphOS.Access.bind_scope_to_node("policy_id", "api_keys_scope", "key_123")
      {:ok, %GraphOS.Entity.Edge{source: "api_keys_scope", target: "key_123"}}
  """
  @spec bind_scope_to_node(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
    {:ok, GraphOS.Entity.Edge.t()} | {:error, any()}
  def bind_scope_to_node(policy_id, scope_id, node_id) do
    edge = GraphOS.Entity.Edge.new(%{
      graph_id: policy_id,
      source: scope_id,
      target: node_id,
      data: %{bound_at: DateTime.utc_now()}
    })

    Store.insert(GraphOS.Entity.Edge, edge)
  end

  @doc """
  Lists all permissions for a specific actor including those from group memberships.

  ## Examples

      iex> GraphOS.Access.list_actor_permissions("user_1")
      {:ok, [%{scope_id: "resource_1", permissions: %{read: true, write: false}}]}
  """
  @spec list_actor_permissions(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_actor_permissions(actor_id) do
    # Get direct permissions
    {:ok, direct_permissions} = list_direct_permissions(actor_id)

    # Get group memberships
    case Store.all(Membership, %{source: actor_id}) do
      {:ok, memberships} when is_list(memberships) and length(memberships) > 0 ->
        # Get permissions for each group
        group_ids = Enum.map(memberships, fn edge -> edge.target end)

        group_permissions =
          Enum.flat_map(group_ids, fn group_id ->
            case list_direct_permissions(group_id) do
              {:ok, perms} ->
                # Add group info to permissions
                Enum.map(perms, fn perm ->
                  Map.put(perm, :via_group, group_id)
                end)
              _ -> []
            end
          end)

        # Combine direct and group permissions
        {:ok, direct_permissions ++ group_permissions}

      _ -> {:ok, direct_permissions}
    end
  end

  @doc """
  Lists direct permissions for an actor or group (excluding inherited permissions).
  """
  @spec list_direct_permissions(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_direct_permissions(target_id) do
    case Store.all(Permission, %{target: target_id}) do
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
      {:ok, [%{target_id: "user_1", target_type: "actor", permissions: %{read: true, write: false}}]}
  """
  @spec list_scope_permissions(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_scope_permissions(scope_id) do
    case Store.all(Permission, %{source: scope_id}) do
      {:ok, edges} ->
        result = Enum.map(edges, fn edge ->
          # Determine if target is actor or group
          target_type = case Store.get(Actor, edge.target) do
            {:ok, _} -> "actor"
            _ -> case Store.get(Group, edge.target) do
              {:ok, _} -> "group"
              _ -> "unknown"
            end
          end

          %{
            target_id: edge.target,
            target_type: target_type,
            permissions: edge.data
          }
        end)
        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all nodes protected by a specific scope.
  """
  @spec list_scope_nodes(GraphOS.Entity.id()) ::
    {:ok, list(map())} | {:error, any()}
  def list_scope_nodes(scope_id) do
    case Store.all(GraphOS.Entity.Edge, %{source: scope_id}) do
      {:ok, edges} ->
        # Filter out permission edges
        result = Enum.filter(edges, fn edge ->
          edge.metadata.module != Permission
        end)
        |> Enum.map(fn edge ->
          %{
            node_id: edge.target,
            bound_at: Map.get(edge.data, :bound_at)
          }
        end)
        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end
