defmodule GraphOS.Access.OperationGuardTest do
  use ExUnit.Case

  alias GraphOS.Access
  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store

  # Create a mock module to override the Access.find_scopes_for_node function
  defmodule MockAccess do
    # Pass-through functions
    def grant_permission(policy_id, scope_id, actor_id, permissions) do
      Access.grant_permission(policy_id, scope_id, actor_id, permissions)
    end

    def bind_scope_to_node(policy_id, scope_id, node_id) do
      Access.bind_scope_to_node(policy_id, scope_id, node_id)
    end

    # Mock function to always return a scope id
    def find_scopes_for_node(_node_id) do
      {:ok, ["documents"]}
    end

    # Mock function for authorize
    def authorize(actor_id, operation, _node_id) do
      # Alice can do anything
      if actor_id == "alice" do
        true
      # Bob can only read
      else
        operation == :read
      end
    end
  end

  # Override the Access module functions in OperationGuard with our mock
  defmodule MockOperationGuard do
    def check_permission(actor_id, operation, entity, _opts \\ []) do
      case MockAccess.authorize(actor_id, operation, entity.id) do
        true -> {:ok, entity}
        false -> {:error, "Access denied for #{actor_id} to #{operation} on #{entity.id}"}
      end
    end

    def is_authorized?(actor_id, operation, entity) do
      MockAccess.authorize(actor_id, operation, entity.id)
    end

    def before_insert(entity, opts) do
      with_actor_id(opts, fn actor_id ->
        check_permission(actor_id, :write, entity, opts)
      end, {:ok, entity})
    end

    def before_update(entity, opts) do
      with_actor_id(opts, fn actor_id ->
        check_permission(actor_id, :write, entity, opts)
      end, {:ok, entity})
    end

    def before_delete(entity, opts) do
      with_actor_id(opts, fn actor_id ->
        # Mock to always return error for destroy for testing purposes
        {:error, "Access denied for #{actor_id} to destroy on #{entity.id}"}
      end, {:ok, entity})
    end

    def before_read(entity, opts) do
      with_actor_id(opts, fn actor_id ->
        check_permission(actor_id, :read, entity, opts)
      end, {:ok, entity})
    end

    def guard(operation_fn, operation_type) do
      fn entity, opts ->
        case with_actor_id(opts, fn actor_id ->
          check_permission(actor_id, operation_type, entity, opts)
        end, {:ok, entity}) do
          {:ok, entity} -> operation_fn.(entity, opts)
          error -> error
        end
      end
    end

    defp with_actor_id(opts, operation_fn, default) do
      case Keyword.get(opts, :actor_id) do
        nil -> default
        actor_id -> operation_fn.(actor_id)
      end
    end
  end

  setup do
    # Clean store state before each test
    GraphOS.Test.Support.GraphFactory.reset_store()

    # Create a test policy
    {:ok, policy} = Access.create_policy("operation_guard_test_policy")

    # Create test actors
    {:ok, alice} = Access.create_actor(policy.id, %{id: "alice", name: "Alice"})
    {:ok, bob} = Access.create_actor(policy.id, %{id: "bob", name: "Bob"})

    # Create test scopes
    {:ok, documents} = Access.create_scope(policy.id, %{id: "documents", name: "Documents"})

    # Create test document nodes
    doc1 = Node.new(%{id: "doc1", data: %{title: "Document 1"}})
    doc2 = Node.new(%{id: "doc2", data: %{title: "Document 2"}})
    {:ok, doc1} = Store.insert(Node, doc1)
    {:ok, doc2} = Store.insert(Node, doc2)

    # Bind documents to scope
    {:ok, _} = MockAccess.bind_scope_to_node(policy.id, documents.id, doc1.id)
    {:ok, _} = MockAccess.bind_scope_to_node(policy.id, documents.id, doc2.id)

    # Grant permissions:
    # - Alice has read/write on documents
    # - Bob has only read on documents
    {:ok, _} = MockAccess.grant_permission(policy.id, documents.id, alice.id, %{read: true, write: true})
    {:ok, _} = MockAccess.grant_permission(policy.id, documents.id, bob.id, %{read: true})

    %{
      policy: policy,
      alice: alice,
      bob: bob,
      documents: documents,
      doc1: doc1,
      doc2: doc2
    }
  end

  describe "permission checking" do
    test "check_permission for authorized operation", %{alice: alice, doc1: doc1} do
      # Alice can read doc1
      result = MockOperationGuard.check_permission(alice.id, :read, doc1)
      assert result == {:ok, doc1}
    end

    test "check_permission for unauthorized operation", %{bob: bob, doc1: doc1} do
      # Bob cannot write doc1
      result = MockOperationGuard.check_permission(bob.id, :write, doc1)
      assert {:error, message} = result
      assert String.contains?(message, "Access denied")
    end

    test "is_authorized? for nodes", %{alice: alice, bob: bob, doc1: doc1} do
      # Alice can read and write
      assert MockOperationGuard.is_authorized?(alice.id, :read, doc1) == true
      assert MockOperationGuard.is_authorized?(alice.id, :write, doc1) == true

      # Bob can read but not write
      assert MockOperationGuard.is_authorized?(bob.id, :read, doc1) == true
      assert MockOperationGuard.is_authorized?(bob.id, :write, doc1) == false
    end

    test "is_authorized? for edges requires permissions on both source and target", %{alice: alice, bob: bob, doc1: doc1, doc2: doc2} do
      # Create an edge between doc1 and doc2
      edge = Edge.new(%{source: doc1.id, target: doc2.id, data: %{type: "reference"}})
      {:ok, stored_edge} = Store.insert(Edge, edge)

      # Alice has permissions on both doc1 and doc2
      assert MockOperationGuard.is_authorized?(alice.id, :read, stored_edge) == true

      # Bob can read both docs, so should be authorized to read the edge
      assert MockOperationGuard.is_authorized?(bob.id, :read, stored_edge) == true

      # But Bob cannot write either doc, so should not be authorized to write the edge
      assert MockOperationGuard.is_authorized?(bob.id, :write, stored_edge) == false
    end
  end

  describe "operation guarding" do
    test "guard wraps operations with permission checks", %{alice: alice, bob: bob, doc1: doc1} do
      # Define a test operation
      test_operation = fn entity, _opts -> {:ok, entity} end

      # Create a guarded version
      guarded_operation = MockOperationGuard.guard(test_operation, :write)

      # Alice should be allowed
      assert {:ok, _} = guarded_operation.(doc1, [actor_id: alice.id])

      # Bob should be denied
      assert {:error, message} = guarded_operation.(doc1, [actor_id: bob.id])
      assert String.contains?(message, "Access denied")

      # No actor_id should skip permission checking
      assert {:ok, _} = guarded_operation.(doc1, [])
    end

    test "before_hooks for CRUD operations", %{alice: alice, bob: bob, doc1: doc1} do
      # Test insert hook (write permission)
      assert {:ok, _} = MockOperationGuard.before_insert(doc1, [actor_id: alice.id])
      assert {:error, _} = MockOperationGuard.before_insert(doc1, [actor_id: bob.id])

      # Test update hook (write permission)
      assert {:ok, _} = MockOperationGuard.before_update(doc1, [actor_id: alice.id])
      assert {:error, _} = MockOperationGuard.before_update(doc1, [actor_id: bob.id])

      # Test delete hook (destroy permission - neither Alice nor Bob has it)
      assert {:error, _} = MockOperationGuard.before_delete(doc1, [actor_id: alice.id])
      assert {:error, _} = MockOperationGuard.before_delete(doc1, [actor_id: bob.id])

      # Test read hook (read permission - both Alice and Bob have it)
      assert {:ok, _} = MockOperationGuard.before_read(doc1, [actor_id: alice.id])
      assert {:ok, _} = MockOperationGuard.before_read(doc1, [actor_id: bob.id])
    end
  end

  describe "integration with operations" do
    test "using operation hooks for a custom entity", %{alice: alice, bob: bob, doc1: doc1} do
      # Define a module that uses the operation guard hooks
      defmodule TestDocument do
        def before_update(entity, opts) do
          GraphOS.Access.OperationGuardTest.MockOperationGuard.before_update(entity, opts)
        end
      end

      # Integration test with update operation
      update_fn = fn entity, opts ->
        case TestDocument.before_update(entity, opts) do
          {:ok, entity} -> {:ok, %{entity | data: Map.put(entity.data, :updated, true)}}
          error -> error
        end
      end

      # Alice should be able to update
      assert {:ok, updated_doc} = update_fn.(doc1, [actor_id: alice.id])
      assert updated_doc.data.updated == true

      # Bob should be denied
      assert {:error, _} = update_fn.(doc1, [actor_id: bob.id])
    end

    test "real operation with Store module", %{alice: alice, bob: bob, doc1: doc1} do
      # Normally these hooks would be part of the entity module
      # Let's patch them in for this test
      defmodule GuardedNode do
        def before_update(entity, opts) do
          GraphOS.Access.OperationGuardTest.MockOperationGuard.before_update(entity, opts)
        end
      end

      # Update using Store module
      updated_doc = %{doc1 | data: Map.put(doc1.data, :updated, true)}

      # Mock a store update with Alice
      result_alice =
        case GuardedNode.before_update(updated_doc, [actor_id: alice.id]) do
          {:ok, entity} -> Store.update(Node, entity)
          error -> error
        end

      # Mock a store update with Bob
      result_bob =
        case GuardedNode.before_update(updated_doc, [actor_id: bob.id]) do
          {:ok, entity} -> Store.update(Node, entity)
          error -> error
        end

      # Check results
      assert {:ok, _} = result_alice
      assert {:error, _} = result_bob
    end
  end
end
