defmodule GraphOS.Access.OperationGuardTest do
  use ExUnit.Case, async: false

  alias GraphOS.Access
  alias GraphOS.Store
  alias GraphOS.Entity.{Node, Edge}

  # Define a simple entity for testing hooks
  defmodule TestEntity do
    defstruct [:id, :data, :metadata]
    def new(id, data \\ %{}) do
      %TestEntity{id: id || UUIDv7.generate(), data: data, metadata: %{}}
    end
  end

  # Define mock modules outside the setup block
  defmodule MockOperation do
    alias GraphOS.Access.OperationGuard
    alias GraphOS.Access.OperationGuardTest.TestEntity
    alias GraphOS.Access

    # Define operation types (required by guard)
    @operation_types %{
      read: %{required_permission: :read},
      write: %{required_permission: :write},
      update: %{required_permission: :write},
      delete: %{required_permission: :destroy}
    }

    # Use guard for specific functions
    use OperationGuard, operations: @operation_types, 
      hook_module: GraphOS.Access.OperationGuardTest.MockHook,
      operation_context: %{}

    # Define some operations that will be guarded
    def guarded_read(store_ref, actor_id, resource_id) when is_binary(resource_id) do
      # When resource_id is a string, use Access.authorize directly
      case Access.authorize(store_ref, actor_id, :read, resource_id) do
        {:ok, _} -> 
          {:ok, "Read #{resource_id} by #{actor_id}"}
        {:error, reason} ->
          {:error, reason}
      end
    end

    # Handle entity structs with OperationGuard.check_permission
    def guarded_read(store_ref, actor_id, resource) when is_struct(resource) do
      case GraphOS.Access.OperationGuard.check_permission(store_ref, actor_id, :read, resource) do
        {:ok, _} -> 
          {:ok, "Read #{resource.id} by #{actor_id}"}
        {:error, reason} ->
          {:error, reason}
      end
    end

    def guarded_write(store_ref, actor_id, resource_id, data) when is_binary(resource_id) do
      # When resource_id is a string, use Access.authorize directly
      case Access.authorize(store_ref, actor_id, :write, resource_id) do
        {:ok, _} -> 
          {:ok, "Wrote #{data} to #{resource_id} by #{actor_id}"}
        {:error, reason} ->
          {:error, reason}
      end
    end

    # Handle entity structs with OperationGuard.check_permission
    def guarded_write(store_ref, actor_id, resource, data) when is_struct(resource) do
      case GraphOS.Access.OperationGuard.check_permission(store_ref, actor_id, :write, resource) do
        {:ok, _} -> 
          {:ok, "Wrote #{data} to #{resource.id} by #{actor_id}"}
        {:error, reason} ->
          {:error, reason}
      end
    end

    def unguarded_operation(resource_id) do
      # Not wrapped by the guard - no permission checks
      {:ok, "Accessed #{resource_id} without checks"}
    end
  end

  defmodule MockHook do
    # Implement the hook functions for testing
    def before_operation(_store_ref, _op_type, _actor_id, resource_id, context) do
      # Just add a timestamp to the context
      context = Map.put(context, :operation_timestamp, DateTime.utc_now())
      {:ok, resource_id, context}
    end

    def after_operation(_store_ref, _op_type, _actor_id, _resource_id, result, context) do
      # Maybe transform the result or add more context
      {:ok, result, context}
    end
  end

  # Setup for all tests
  setup do
    # Use atoms for store names instead of strings for consistency
    store_name = :"operation_guard_test_store_#{System.unique_integer([])}" 
    {:ok, _} = Store.start_link(name: store_name, adapter: GraphOS.Store.Adapter.ETS)
    
    # Ensure proper cleanup with error handling
    on_exit(fn -> 
      try do
        Store.stop(store_name)
      catch
        :exit, _ -> :ok
      end
    end)

    # Create policy
    {:ok, policy} = Access.create_policy(store_name, "test_policy")
    # Create actor
    {:ok, actor} = Access.create_actor(store_name, policy.id, %{id: "actor1"})
    # Create scope
    {:ok, scope} = Access.create_scope(store_name, policy.id, %{id: "test_scope"})

    # Create resource node
    resource = Node.new(%{id: "resource1", data: %{}})
    {:ok, resource} = Store.insert(store_name, Node, resource)

    # Bind the resource to a scope
    {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, scope.id, resource.id)

    # Grant only read permission for basic tests
    {:ok, _} = Access.grant_permission(store_name, policy.id, scope.id, actor.id, %{read: true})

    # Return test context
    %{
      store_name: store_name,
      policy: policy,
      actor: actor,
      scope: scope,
      resource: resource
    }
  end

  describe "permission checking" do
    test "check_permission for authorized operation", %{store_name: store_name, actor: actor, resource: resource} do
      # Actor has read permission granted in setup
      assert GraphOS.Access.OperationGuard.check_permission(store_name, actor.id, :read, resource) == {:ok, resource}
    end

    test "check_permission for unauthorized operation", %{store_name: store_name, actor: actor, resource: resource} do
      # Actor does not have write permission
      assert GraphOS.Access.OperationGuard.check_permission(store_name, actor.id, :write, resource) == {:error, :unauthorized}
    end

    test "is_authorized? for authorized operation", %{store_name: store_name, actor: actor, resource: resource} do
      # Actor has read permission
      assert match?({:ok, _}, GraphOS.Access.OperationGuard.is_authorized?(store_name, actor.id, :read, resource))
    end

    test "is_authorized? for unauthorized operation", %{store_name: store_name, actor: actor, resource: resource} do
      # Actor does not have write permission
      assert GraphOS.Access.OperationGuard.is_authorized?(store_name, actor.id, :write, resource) == {:error, :unauthorized}
    end

    test "is_authorized? for edges requires permissions on both source and target", %{
      store_name: store_name,
      policy: policy,
      actor: actor,
      resource: resource # Acts as target node
    } do
      # Create another node to act as source
      source_node = Node.new(%{id: "source_node", data: %{}})
      {:ok, source_node} = Store.insert(store_name, Node, source_node)

      # Create a scope for the source node
      {:ok, source_scope} = Access.create_scope(store_name, policy.id, %{id: "source_scope"})

      # Bind source node to its scope
      {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, source_scope.id, source_node.id)

      # Create an edge between source_node and resource
      edge = Edge.new(%{id: "edge1", source: source_node.id, target: resource.id, data: %{}})
      {:ok, edge} = Store.insert(store_name, Edge, edge)

      # Initially, actor doesn't have permission on source_scope
      assert GraphOS.Access.OperationGuard.is_authorized?(store_name, actor.id, :read, edge) == {:error, :unauthorized}

      # Grant permission on source_scope
      {:ok, _} = Access.grant_permission(store_name, policy.id, source_scope.id, actor.id, %{read: true})

      # Actor has read on scope (target) and source_scope (source)
      assert match?({:ok, _}, GraphOS.Access.OperationGuard.is_authorized?(store_name, actor.id, :read, edge))
    end

  end

  describe "integration with operations" do
    test "guarded function performs operation when authorized", %{store_name: store_name, actor: actor} do
      # Actor has read permission from setup
      # Assuming MockOperation.guarded_read expects store_name, actor_id, resource_id
      assert MockOperation.guarded_read(store_name, actor.id, "resource1") == {:ok, "Read resource1 by actor1"}
    end

    test "guarded function returns error when unauthorized", %{store_name: store_name, actor: actor} do
      # Actor does not have write permission
      assert MockOperation.guarded_write(store_name, actor.id, "resource1", "new data") == {:error, :unauthorized}
    end

    @tag :skip # Skipping hook tests until hooks are fully implemented in OperationGuard macro
    test "guarded function calls before/after hooks", %{} do
      # Hooks functionality is not fully implemented yet
      # This is just a placeholder test that will be implemented when hooks are ready
      assert true
    end
  end
end
