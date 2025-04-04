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

  use Boundary,
    deps: [GraphOS.Store, GraphOS.Entity],
    exports: [Actor, Group, Membership, Scope, Permission, Policy, OperationGuard]

  alias GraphOS.Access.{Actor, Group, Membership, Scope, Permission, Policy}

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
  Creates a new policy with the given name using the default store.

  ## Examples

      iex> GraphOS.Access.create_policy("my_policy")
      {:ok, %GraphOS.Access.Policy{name: "my_policy"}}
  """
  @spec create_policy(binary()) :: {:ok, GraphOS.Access.Policy.t()} | {:error, any()}
  def create_policy(name) do
    create_policy(:default, name)
  end

  @doc """
  Creates a new policy with the given name in the specified store.

  ## Examples

      iex> GraphOS.Access.create_policy(:my_store, "my_policy")
      {:ok, %GraphOS.Access.Policy{name: "my_policy"}}
  """
  @spec create_policy(term(), binary()) :: {:ok, GraphOS.Access.Policy.t()} | {:error, any()}
  def create_policy(store_ref, name) do
    # Create a Policy struct directly instead of using Policy.new
    policy = %Policy{
      id: UUIDv7.generate(),
      name: name
    }

    GraphOS.Store.insert(store_ref, Policy, policy)
  end

  @doc """
  Creates a new actor in the specified policy using the default store.

  ## Examples

      iex> GraphOS.Access.create_actor("policy_id", %{id: "user_1", name: "John Doe"})
      {:ok, %GraphOS.Access.Actor{id: "user_1", data: %{name: "John Doe"}}}
  """
  @spec create_actor(GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Actor.t()} | {:error, any()}
  def create_actor(policy_id, attrs) do
    create_actor(:default, policy_id, attrs)
  end

  @doc """
  Creates a new actor in the specified policy and store.

  ## Examples

      iex> GraphOS.Access.create_actor(:my_store, "policy_id", %{id: "user_1", name: "John Doe"})
      {:ok, %GraphOS.Access.Actor{id: "user_1", data: %{name: "John Doe"}}}
  """
  @spec create_actor(term(), GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Actor.t()} | {:error, any()}
  def create_actor(store_ref, policy_id, attrs) do
    actor = Actor.new(%{
      graph_id: policy_id,
      id: Map.get(attrs, :id, UUIDv7.generate()),
      data: attrs
    })

    GraphOS.Store.insert(store_ref, Actor, actor)
  end

  @doc """
  Creates a new group in the specified policy and store.

  ## Examples

      iex> GraphOS.Access.create_group(:my_store, "policy_id", %{id: "group_1", name: "Admins"})
      {:ok, %GraphOS.Access.Group{id: "group_1", data: %{name: "Admins"}}}
  """
  @spec create_group(term(), GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Group.t()} | {:error, any()}
  def create_group(store_ref, policy_id, attrs) do
    group =
      Group.new(%{
        graph_id: policy_id,
        id: Map.get(attrs, :id, UUIDv7.generate()),
        data: attrs
      })

    GraphOS.Store.insert(store_ref, Group, group)
  end

  @doc """
  Creates a group in the policy using the default store.

  ## Parameters

  - `policy_id` - The ID of the policy
  - `attrs` - Map of attributes for the group

  ## Examples

      iex> GraphOS.Access.create_group("policy_id", %{id: "group_1", name: "Admins"})
      {:ok, %GraphOS.Access.Group{id: "group_1", data: %{name: "Admins"}}}
  """
  @spec create_group(GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Group.t()} | {:error, any()}
  def create_group(policy_id, attrs) do
    create_group(:default, policy_id, attrs)
  end

  @doc """
  Adds an actor to a group using the default store.

  ## Examples

      iex> GraphOS.Access.add_to_group("policy_id", "actor_1", "group_1")
      {:ok, %GraphOS.Access.Membership{source: "actor_1", target: "group_1"}}
  """
  @spec add_to_group(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          {:ok, GraphOS.Access.Membership.t()} | {:error, any()}
  def add_to_group(policy_id, actor_id, group_id) do
    add_to_group(:default, policy_id, actor_id, group_id)
  end

  @doc """
  Adds an actor to a group in a specific store.

  ## Examples

      iex> GraphOS.Access.add_to_group(:my_store, "policy_id", "actor_1", "group_1")
      {:ok, %GraphOS.Access.Membership{source: "actor_1", target: "group_1"}}
  """
  @spec add_to_group(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          {:ok, GraphOS.Access.Membership.t()} | {:error, any()}
  def add_to_group(store_ref, policy_id, actor_id, group_id) do
    membership =
      Membership.new(%{
        graph_id: policy_id,
        source: actor_id,
        target: group_id,
        data: %{joined_at: DateTime.utc_now()}
      })

    GraphOS.Store.insert(store_ref, Membership, membership)
  end

  @doc """
  Creates a new scope in the specified policy using the default store.

  ## Examples

      iex> GraphOS.Access.create_scope("policy_id", %{id: "resource_1", name: "API Keys"})
      {:ok, %GraphOS.Access.Scope{id: "resource_1", data: %{name: "API Keys"}}}
  """
  @spec create_scope(GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Scope.t()} | {:error, any()}
  def create_scope(policy_id, attrs) do
    create_scope(:default, policy_id, attrs)
  end

  @doc """
  Creates a new scope in the specified policy and store.

  ## Examples

      iex> GraphOS.Access.create_scope(:my_store, "policy_id", %{id: "resource_1", name: "API Keys"})
      {:ok, %GraphOS.Access.Scope{id: "resource_1", data: %{name: "API Keys"}}}
  """
  @spec create_scope(term(), GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Scope.t()} | {:error, any()}
  def create_scope(store_ref, policy_id, attrs) do
    scope =
      Scope.new(%{
        graph_id: policy_id,
        id: Map.get(attrs, :id, UUIDv7.generate()),
        data: attrs
      })

    GraphOS.Store.insert(store_ref, Scope, scope)
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
      {:ok, %GraphOS.Access.Permission{source: "resource_1", target: "user_1", data: %{read: true, write: true}}}
  """
  @spec grant_permission(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id(), map()) ::
          {:ok, GraphOS.Access.Permission.t()} | {:error, any()}
  def grant_permission(policy_id, scope_id, target_id, permissions) do
    grant_permission(:default, policy_id, scope_id, target_id, permissions)
  end

  @doc """
  Creates a permission edge between a scope and an actor or group in a specific store.

  ## Parameters

  - `store_ref` - The store reference
  - `policy_id` - The ID of the policy
  - `scope_id` - The ID of the scope (source)
  - `target_id` - The ID of the actor or group (target)
  - `permissions` - Map of permissions (read, write, execute, destroy)

  ## Examples

      iex> GraphOS.Access.grant_permission(:my_store, "policy_id", "resource_1", "user_1", %{read: true, write: true})
      {:ok, %GraphOS.Access.Permission{source: "resource_1", target: "user_1", data: %{read: true, write: true}}}
  """
  @spec grant_permission(
          term(),
          GraphOS.Entity.id(),
          GraphOS.Entity.id(),
          GraphOS.Entity.id(),
          map()
        ) ::
          {:ok, GraphOS.Access.Permission.t()} | {:error, any()}
  def grant_permission(store_ref, policy_id, scope_id, target_id, permissions) do
    # Validate permissions map
    validated_permissions = Map.take(permissions, @permission_types)

    edge =
      Permission.new(%{
        graph_id: policy_id,
        source: scope_id,
        target: target_id,
        data: validated_permissions
      })

    GraphOS.Store.insert(store_ref, Permission, edge)
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
    has_permission?(:default, scope_id, actor_id, permission)
  end

  @doc """
  Checks if an actor has a specific permission on a scope in a specific store.
  This function also checks group memberships.

  ## Examples

      iex> GraphOS.Access.has_permission?(:my_store, "resource_1", "user_1", :read)
      true
  """
  @spec has_permission?(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_permission?(store_ref, scope_id, actor_id, permission) when is_atom(permission) do
    # First check direct permissions
    case has_permission_tuple(store_ref, scope_id, actor_id, permission) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Checks if an actor has a direct permission on a scope, without considering group memberships.
  """
  @spec has_direct_permission?(GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_direct_permission?(scope_id, target_id, permission) when is_atom(permission) do
    case GraphOS.Store.all(Permission, %{source: scope_id, target: target_id}) do
      {:ok, []} ->
        false

      {:ok, edges} ->
        # Check if any edge grants the requested permission
        if Enum.any?(edges, fn edge -> Map.get(edge.data, permission, false) end) do
          true
        else
          false
        end

      {:error, _} ->
        false
    end
  end

  @doc """
  Authorizes an actor to perform an operation on a node using the default store.

  This is a convenience wrapper around authorize/4 that uses the default store.

  ## Parameters

  - `actor_id` - The ID of the actor
  - `operation` - The operation to check (e.g., :read, :write)
  - `node_id` - The ID of the node to check permissions for

  ## Examples

      iex> GraphOS.Access.authorize("actor_1", :read, "document_1")
      {:ok, "document_1"}
  """
  @spec authorize(GraphOS.Entity.id(), atom(), GraphOS.Entity.id()) :: 
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def authorize(actor_id, operation, node_id) when is_atom(operation) do
    authorize(:default, actor_id, operation, node_id)
  end

  @doc """
  Authorizes an actor to perform an operation on a node.

  The authorization process works as follows:
  1. Find all scopes associated with the node
  2. For each scope, check if the actor has the required permission
  3. If the actor has the permission in any scope, return true

  ## Parameters

  - `store_ref` - The store reference
  - `actor_id` - The ID of the actor
  - `operation` - The operation to check (e.g., :read, :write)
  - `node_id` - The ID of the node to check permissions for

  ## Examples

      iex> GraphOS.Access.authorize(:my_store, "actor_1", :read, "document_1")
      {:ok, "document_1"}
  """
  @spec authorize(term(), GraphOS.Entity.id(), atom(), GraphOS.Entity.id()) :: 
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def authorize(store_ref, actor_id, operation, node_id) when is_atom(operation) do
    # Find all scopes that the node belongs to in the store
    case find_scopes_for_node_in_store(store_ref, node_id) do
      {:ok, scope_ids} when is_list(scope_ids) and length(scope_ids) > 0 ->
        # Check if actor has permission for the operation on any of the scopes
        if Enum.any?(scope_ids, fn scope_id ->
            case has_permission_in_store?(store_ref, scope_id, actor_id, operation) do
              true -> true
              false -> false
            end
          end) do
          {:ok, node_id}
        else
          {:error, :unauthorized}
        end

      _ ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Authorizes an actor to perform an operation on a node.
  Returns true if authorized, false otherwise.

  ## Parameters

  - `store_ref` - The store reference
  - `actor_id` - The ID of the actor
  - `operation` - The operation to check (e.g., :read, :write)
  - `node_id` - The ID of the node to check permissions for

  ## Examples

      iex> GraphOS.Access.authorize?(:my_store, "actor_1", :read, "document_1")
      true
  """
  @spec authorize?(term(), GraphOS.Entity.id(), atom(), GraphOS.Entity.id()) :: boolean()
  def authorize?(store_ref, actor_id, operation, node_id) when is_atom(operation) do
    case authorize(store_ref, actor_id, operation, node_id) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Find all scopes that a node belongs to.

  A node belongs to a scope if there's an edge from the node to the scope with bound_at data attribute.

  ## Examples

      iex> GraphOS.Access.find_scopes_for_node("node_123")
      {:ok, ["scope_1", "scope_2"]}
  """
  @spec find_scopes_for_node(GraphOS.Entity.id()) ::
          {:ok, [GraphOS.Entity.id()]} | {:error, any()}
  def find_scopes_for_node(node_id) do
    find_scopes_for_node_in_store(:default, node_id)
  end

  @doc """
  Find all scopes that a node belongs to in a specific store.

  A node belongs to a scope if there's an edge from the node to the scope with bound_at data attribute.

  ## Examples

      iex> GraphOS.Access.find_scopes_for_node_in_store(:my_store, "node_123")
      {:ok, ["scope_1", "scope_2"]}
  """
  @spec find_scopes_for_node_in_store(term(), GraphOS.Entity.id()) ::
          {:ok, [GraphOS.Entity.id()]} | {:error, any()}
  def find_scopes_for_node_in_store(store_ref, node_id) do
    # Query using the GraphOS.Entity.Edge module to find edges where node is the target
    case GraphOS.Store.all(store_ref, GraphOS.Entity.Edge, %{target: node_id}) do
      {:ok, edges} ->
        # Get all sources pointing to the node (which should be scopes)
        # Filter edges that have bound_at in data to ensure they are scope binding edges
        scope_ids =
          edges
          |> Enum.filter(fn edge -> Map.has_key?(edge.data, :bound_at) end)
          |> Enum.map(fn edge -> edge.source end)

        {:ok, scope_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if an actor has a specific permission on a scope in a specific store.
  This function also checks group memberships.
  """
  @spec has_permission_in_store?(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) :: boolean()
  def has_permission_in_store?(store_ref, scope_id, actor_id, permission)
      when is_atom(permission) do
    # First check direct permissions
    case has_permission_tuple(store_ref, scope_id, actor_id, permission) do
      {:ok, _} -> 
        # Direct permission exists
        true
      {:error, :unauthorized} ->
        # If not, check for group memberships and their permissions
        case GraphOS.Store.all(store_ref, Membership, %{source: actor_id}) do
          {:ok, memberships} when is_list(memberships) and length(memberships) > 0 ->
            # Get all groups the actor belongs to
            group_ids = Enum.map(memberships, fn edge -> edge.target end)

            # Check if any group has the permission
            Enum.any?(group_ids, fn group_id ->
              case has_permission_tuple(store_ref, scope_id, group_id, permission) do
                {:ok, _} -> true
                {:error, :unauthorized} -> false
              end
            end)

          _ ->
            false
        end
    end
  end

  @doc """
  Checks if an actor has a direct permission on a scope in a specific store.
  """
  @spec has_direct_permission_in_store?(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) ::
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def has_direct_permission_in_store?(store_ref, scope_id, target_id, permission)
      when is_atom(permission) do
    case GraphOS.Store.all(store_ref, Permission, %{source: scope_id, target: target_id}) do
      {:ok, []} ->
        {:error, :unauthorized}

      {:ok, edges} ->
        # Check if any edge grants the requested permission
        if Enum.any?(edges, fn edge -> Map.get(edge.data, permission, false) end) do
          {:ok, target_id}
        else
          {:error, :unauthorized}
        end

      {:error, reason} ->
        IO.puts("Error checking direct permissions: #{inspect(reason)}")
        {:error, :unauthorized}
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
    bind_scope_to_node(:default, policy_id, scope_id, node_id)
  end

  @doc """
  Binds a scope to a node in a specific store, establishing that the node is protected by the scope.

  ## Examples

      iex> GraphOS.Access.bind_scope_to_node(:my_store, "policy_id", "scope_1", "node_1")
      {:ok, %GraphOS.Entity.Edge{source: "scope_1", target: "node_1"}}
  """
  @spec bind_scope_to_node(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          {:ok, GraphOS.Entity.Edge.t()} | {:error, any()}
  def bind_scope_to_node(store_ref, policy_id, scope_id, node_id) do
    # Create the edge with scope as source and node as target
    edge =
      GraphOS.Entity.Edge.new(%{
        graph_id: policy_id,
        source: scope_id, # scope is the source
        target: node_id,  # node is the target
        data: %{bound_at: DateTime.utc_now()}
      })

    GraphOS.Store.insert(store_ref, GraphOS.Entity.Edge, edge)
  end

  @doc """
  Lists all permissions (direct and inherited) for an actor using the default store.

  ## Examples

      iex> GraphOS.Access.list_actor_permissions("user_1")
      {:ok, [%{permission: permission1, scope: scope1}, %{permission: permission2, scope: scope2}]}
  """
  @spec list_actor_permissions(GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_actor_permissions(actor_id) do
    list_actor_permissions(:default, actor_id)
  end

  @doc """
  Lists all permissions (direct and inherited) for an actor in a specific store.

  ## Examples

      iex> GraphOS.Access.list_actor_permissions(:my_store, "user_1")
      {:ok, [%{permission: permission1, scope: scope1}, %{permission: permission2, scope: scope2}]}
  """
  @spec list_actor_permissions(term(), GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_actor_permissions(store_ref, actor_id) do
    # Get direct permissions
    {:ok, direct_permissions} = list_direct_permissions(store_ref, actor_id)

    # Get group memberships
    case get_actor_groups(store_ref, actor_id) do
      {:ok, group_ids} when is_list(group_ids) and length(group_ids) > 0 ->
        # Get permissions through groups
        group_permissions =
          Enum.flat_map(group_ids, fn group_id ->
            case list_direct_permissions(store_ref, group_id) do
              {:ok, perms} ->
                # Add info about which group this permission came from
                Enum.map(perms, fn perm ->
                  Map.put(perm, :via_group, group_id)
                end)

              _ ->
                []
            end
          end)

        # Combine direct and group permissions
        {:ok, direct_permissions ++ group_permissions}

      _ ->
        {:ok, direct_permissions}
    end
  end

  @doc """
  Helper function to get all groups an actor belongs to in a specific store.
  """
  @spec get_actor_groups(term(), GraphOS.Entity.id()) ::
          {:ok, [GraphOS.Entity.id()]} | {:error, any()}
  def get_actor_groups(store_ref, actor_id) do
    case GraphOS.Store.all(store_ref, Membership, %{source: actor_id}) do
      {:ok, memberships} ->
        group_ids = Enum.map(memberships, fn edge -> edge.target end)
        {:ok, group_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists direct permissions for an actor or group (excluding inherited permissions).
  """
  @spec list_direct_permissions(GraphOS.Entity.id()) ::
          {:ok, list(map())} | {:error, any()}
  def list_direct_permissions(target_id) do
    list_direct_permissions(:default, target_id)
  end

  @doc """
  Lists direct permissions for an actor or group in a specific store (excluding inherited permissions).
  """
  @spec list_direct_permissions(term(), GraphOS.Entity.id()) ::
          {:ok, list(map())} | {:error, any()}
  def list_direct_permissions(store_ref, target_id) do
    case GraphOS.Store.all(store_ref, Permission, %{target: target_id}) do
      {:ok, edges} ->
        result =
          Enum.map(edges, fn edge ->
            # Get scope details
            scope_details =
              case GraphOS.Store.get(store_ref, Scope, edge.source) do
                {:ok, scope} -> scope
                _ -> %{id: edge.source, data: %{}}
              end

            %{
              scope_id: edge.source,
              scope: scope_details,
              permissions: edge.data
            }
          end)

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
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
    case GraphOS.Store.all(Permission, %{source: scope_id}) do
      {:ok, edges} ->
        result =
          Enum.map(edges, fn edge ->
            # Determine if target is actor or group
            target_type =
              case GraphOS.Store.get(Actor, edge.target) do
                {:ok, _} ->
                  "actor"

                _ ->
                  case GraphOS.Store.get(Group, edge.target) do
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

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all permissions granted on a scope in a specific store.

  ## Examples

      iex> GraphOS.Access.list_scope_permissions(:my_store, "resource_1")
      {:ok, [%{target_id: "user_1", target_type: "actor", permissions: %{read: true, write: false}}]}
  """
  @spec list_scope_permissions(term(), GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_scope_permissions(store_ref, scope_id) do
    case GraphOS.Store.all(store_ref, Permission, %{source: scope_id}) do
      {:ok, permissions} ->
        # For each permission, get the target actor or group details
        result =
          Enum.map(permissions, fn perm ->
            target_type =
              case GraphOS.Store.get(store_ref, Actor, perm.target) do
                {:ok, _} ->
                  "actor"

                _ ->
                  case GraphOS.Store.get(store_ref, Group, perm.target) do
                    {:ok, _} -> "group"
                    _ -> "unknown"
                  end
              end

            %{
              target_id: perm.target,
              target_type: target_type,
              permissions: perm.data
            }
          end)

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all nodes protected by a specific scope.
  """
  @spec list_scope_nodes(GraphOS.Entity.id()) ::
          {:ok, list(map())} | {:error, any()}
  def list_scope_nodes(scope_id) do
    list_scope_nodes(:default, scope_id)
  end

  @doc """
  Lists all nodes that belong to a scope in a specific store.

  ## Examples

      iex> GraphOS.Access.list_scope_nodes(:my_store, "resource_1")
      {:ok, [node1, node2, node3]}
  """
  @spec list_scope_nodes(term(), GraphOS.Entity.id()) ::
          {:ok, list(map())} | {:error, any()}
  def list_scope_nodes(store_ref, scope_id) do
    # Look for edges where the scope is the source (meaning nodes are bound to this scope)
    case GraphOS.Store.all(store_ref, GraphOS.Entity.Edge, %{source: scope_id}) do
      {:ok, edges} ->
        # Filter for edges that have bound_at data property, which indicates scope binding
        result =
          Enum.filter(edges, fn edge ->
            Map.has_key?(edge.data, :bound_at)
          end)
          |> Enum.map(fn edge ->
            # Look up the actual Node to get more details
            case GraphOS.Store.get(store_ref, GraphOS.Entity.Node, edge.target) do
              {:ok, node} ->
                %{
                  # Use node.id for the node_id property
                  node_id: node.id,
                  bound_at: Map.get(edge.data, :bound_at),
                  node: node
                }
              _ ->
                %{
                  node_id: edge.target,
                  bound_at: Map.get(edge.data, :bound_at)
                }
            end
          end)

        {:ok, result}

      error ->
        error
    end
  end

  @doc """
  Checks if an actor is a member of a group using the default store.

  ## Examples

      iex> GraphOS.Access.is_member?("actor_1", "group_1")
      true
  """
  @spec is_member?(GraphOS.Entity.id(), GraphOS.Entity.id()) :: boolean()
  def is_member?(actor_id, group_id) do
    is_member?(:default, actor_id, group_id)
  end

  @doc """
  Checks if an actor is a member of a group using a specific store.

  ## Examples

      iex> GraphOS.Access.is_member?(:my_store, "actor_1", "group_1")
      true
  """
  @spec is_member?(term(), GraphOS.Entity.id(), GraphOS.Entity.id()) :: boolean()
  def is_member?(store_ref, actor_id, group_id) do
    case is_member_tuple(store_ref, actor_id, group_id) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @doc """
  Checks if an actor is a member of a group and returns {:ok, actor_id} or :error.
  """
  @spec is_member_tuple(term(), GraphOS.Entity.id(), GraphOS.Entity.id()) :: 
          {:ok, GraphOS.Entity.id()} | :error
  def is_member_tuple(store_ref, actor_id, group_id) do
    case GraphOS.Store.all(store_ref, Membership, %{source: actor_id, target: group_id}) do
      {:ok, []} -> :error
      {:ok, _memberships} -> {:ok, actor_id}
      {:error, _reason} -> :error
    end
  end

  @doc """
  Removes an actor from a group using the default store.

  ## Examples

      iex> GraphOS.Access.remove_from_group("policy_id", "actor_1", "group_1")
      {:ok, :removed}
  """
  @spec remove_from_group(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          {:ok, :removed} | {:error, any()}
  def remove_from_group(policy_id, actor_id, group_id) do
    remove_from_group(:default, policy_id, actor_id, group_id)
  end

  @doc """
  Removes an actor from a group in a specific store.

  ## Examples

      iex> GraphOS.Access.remove_from_group(:my_store, "policy_id", "actor_1", "group_1")
      {:ok, :removed}
  """
  @spec remove_from_group(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          {:ok, :removed} | {:error, any()}
  def remove_from_group(store_ref, _policy_id, actor_id, group_id) do
    # Find and delete all membership edges between actor and group
    case GraphOS.Store.all(store_ref, Membership, %{source: actor_id, target: group_id}) do
      {:ok, memberships} ->
        # Delete each membership edge
        Enum.each(memberships, fn membership ->
          GraphOS.Store.delete(store_ref, Membership, membership.id)
        end)
        {:ok, :removed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all members of a group using the default store.

  ## Examples

      iex> GraphOS.Access.list_group_members("group_1")
      {:ok, [%{actor_id: "actor_1", joined_at: ~U[2023-01-01 00:00:00Z]}, ...]}
  """
  @spec list_group_members(GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_group_members(group_id) do
    list_group_members(:default, group_id)
  end

  @doc """
  Lists all members of a group in a specific store.

  ## Examples

      iex> GraphOS.Access.list_group_members(:my_store, "group_1")
      {:ok, [%{actor_id: "actor_1", joined_at: ~U[2023-01-01 00:00:00Z]}, ...]}
  """
  @spec list_group_members(term(), GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_group_members(store_ref, group_id) do
    case GraphOS.Store.all(store_ref, Membership, %{target: group_id}) do
      {:ok, memberships} ->
        # Format memberships for easy consumption
        formatted_memberships = Enum.map(memberships, fn membership ->
          %{
            actor_id: membership.source,
            joined_at: Map.get(membership.data, :joined_at),
            membership_id: membership.id
          }
        end)

        {:ok, formatted_memberships}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all groups an actor belongs to using the default store.

  ## Examples

      iex> GraphOS.Access.list_actor_groups("actor_1")
      {:ok, [%{group_id: "group_1", joined_at: ~U[2023-01-01 00:00:00Z]}, ...]}
  """
  @spec list_actor_groups(GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_actor_groups(actor_id) do
    list_actor_groups(:default, actor_id)
  end

  @doc """
  Lists all groups an actor belongs to in a specific store.

  ## Examples

      iex> GraphOS.Access.list_actor_groups(:my_store, "actor_1")
      {:ok, [%{group_id: "group_1", joined_at: ~U[2023-01-01 00:00:00Z]}, ...]}
  """
  @spec list_actor_groups(term(), GraphOS.Entity.id()) :: {:ok, [map()]} | {:error, any()}
  def list_actor_groups(store_ref, actor_id) do
    case GraphOS.Store.all(store_ref, Membership, %{source: actor_id}) do
      {:ok, memberships} ->
        # Format memberships for easy consumption
        formatted_memberships = Enum.map(memberships, fn membership ->
          %{
            group_id: membership.target,
            joined_at: Map.get(membership.data, :joined_at),
            membership_id: membership.id
          }
        end)

        {:ok, formatted_memberships}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Revokes a permission between a scope and an actor or group using the default store.

  ## Examples

      iex> GraphOS.Access.revoke_permission("policy_id", "scope_1", "user_1")
      :ok
  """
  @spec revoke_permission(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          :ok | {:error, any()}
  def revoke_permission(policy_id, scope_id, target_id) do
    revoke_permission(:default, policy_id, scope_id, target_id)
  end

  @doc """
  Revokes a permission between a scope and an actor or group in a specific store.

  ## Examples

      iex> GraphOS.Access.revoke_permission(:my_store, "policy_id", "scope_1", "user_1")
      :ok
  """
  @spec revoke_permission(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          :ok | {:error, any()}
  def revoke_permission(store_ref, _policy_id, scope_id, target_id) do
    # Find and delete all permission edges between scope and target
    case GraphOS.Store.all(store_ref, Permission, %{source: scope_id, target: target_id}) do
      {:ok, permissions} ->
        # Delete each permission edge
        Enum.each(permissions, fn perm ->
          GraphOS.Store.delete(store_ref, Permission, perm.id)
        end)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unbinds a scope from a node using the default store.

  ## Examples

      iex> GraphOS.Access.unbind_scope_from_node("policy_id", "scope_1", "node_1")
      :ok
  """
  @spec unbind_scope_from_node(GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          :ok | {:error, any()}
  def unbind_scope_from_node(policy_id, scope_id, node_id) do
    unbind_scope_from_node(:default, policy_id, scope_id, node_id)
  end

  @doc """
  Unbinds a scope from a node in a specific store.

  ## Examples

      iex> GraphOS.Access.unbind_scope_from_node(:my_store, "policy_id", "scope_1", "node_1")
      :ok
  """
  @spec unbind_scope_from_node(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), GraphOS.Entity.id()) ::
          :ok | {:error, any()}
  def unbind_scope_from_node(store_ref, _policy_id, scope_id, node_id) do
    # Find and delete all binding edges between scope and node
    case GraphOS.Store.all(store_ref, GraphOS.Entity.Edge, %{source: scope_id, target: node_id}) do
      {:ok, edges} ->
        # Delete all binding edges
        bindings = Enum.filter(edges, fn edge -> Map.has_key?(edge.data, :bound_at) end)
        Enum.each(bindings, fn edge ->
          GraphOS.Store.delete(store_ref, GraphOS.Entity.Edge, edge.id)
        end)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if an actor has a specific permission on a scope.
  This function also checks group memberships.

  ## Examples

      iex> GraphOS.Access.has_permission_tuple("resource_1", "user_1", :read)
      {:ok, "user_1"}
  """
  @spec has_permission_tuple(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) ::
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def has_permission_tuple(store_ref, scope_id, actor_id, permission) when is_atom(permission) do
    # Check direct permissions
    case check_direct_permission(store_ref, scope_id, actor_id, permission) do
      {:ok, _} ->
        # Direct permission exists
        {:ok, actor_id}

      {:error, _} ->
        # If not, check for group memberships and their permissions
        case check_group_permissions(store_ref, scope_id, actor_id, permission) do
          {:ok, _} -> {:ok, actor_id}
          {:error, _} -> {:error, :unauthorized}
        end
    end
  end

  @doc """
  Checks if an actor has a direct permission on a scope, without considering group memberships.
  """
  @spec check_direct_permission(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) ::
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def check_direct_permission(store_ref, scope_id, target_id, permission) when is_atom(permission) do
    case GraphOS.Store.all(store_ref, Permission, %{source: scope_id, target: target_id}) do
      {:ok, []} ->
        {:error, :unauthorized}

      {:ok, edges} ->
        # Check if any edge grants the requested permission
        if Enum.any?(edges, fn edge -> Map.get(edge.data, permission, false) end) do
          {:ok, target_id}
        else
          {:error, :unauthorized}
        end

      {:error, reason} ->
        IO.puts("Error checking direct permissions: #{inspect(reason)}")
        {:error, :unauthorized}
    end
  end

  @doc """
  Checks if an actor has a permission through group membership.
  """
  @spec check_group_permissions(term(), GraphOS.Entity.id(), GraphOS.Entity.id(), atom()) ::
          {:ok, GraphOS.Entity.id()} | {:error, :unauthorized}
  def check_group_permissions(store_ref, scope_id, actor_id, permission) when is_atom(permission) do
    # Get all groups the actor belongs to
    case GraphOS.Store.all(store_ref, Membership, %{source: actor_id}) do
      {:ok, memberships} ->
        # Get all groups the actor belongs to
        group_ids = Enum.map(memberships, fn edge -> edge.target end)

        # Check if any group has the permission
        Enum.find_value(
          group_ids,
          {:error, :unauthorized},
          fn group_id ->
            case check_direct_permission(store_ref, scope_id, group_id, permission) do
              {:ok, _} -> {:ok, actor_id}
              {:error, :unauthorized} -> false
            end
          end
        )

      {:error, reason} ->
        IO.puts("Error checking group permissions: #{inspect(reason)}")
        {:error, :unauthorized}
    end
  end
end
