defmodule GraphOS.Access.ActorScopeTest do
  use ExUnit.Case, async: false

  alias GraphOS.Access
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS
  alias GraphOS.Entity.Node

  setup do
    # Generate a truly unique store name for this test
    store_name = String.to_atom("actor_scope_test_store_#{System.unique_integer([:positive, :monotonic])}")

    # Start the store for this test
    {:ok, _pid} = Store.start_link(name: store_name, adapter: ETS)

    # Create a test policy for all tests within this store
    {:ok, policy} = Access.create_policy(store_name, "test_policy")

    # Create test actors
    {:ok, alice} = Access.create_actor(store_name, policy.id, %{id: "alice", name: "Alice"})
    {:ok, bob} = Access.create_actor(store_name, policy.id, %{id: "bob", name: "Bob"})

    # Create test groups
    {:ok, admins} = Access.create_group(store_name, policy.id, %{id: "admins", name: "Administrators"})
    {:ok, users} = Access.create_group(store_name, policy.id, %{id: "users", name: "Regular Users"})

    # Create test scopes
    {:ok, documents} = Access.create_scope(store_name, policy.id, %{id: "documents", name: "Documents"})
    {:ok, settings} = Access.create_scope(store_name, policy.id, %{id: "settings", name: "System Settings"})

    # Create a test node (resource)
    test_node = Node.new(%{id: "test_node_1", data: %{content: "Some data"}})
    {:ok, stored_test_node} = Store.insert(store_name, Node, test_node)

    # Bind the test node to the documents scope
    {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, documents.id, stored_test_node.id)
    
    # Return context map for tests
    context = %{
      store_name: store_name,
      policy: policy,
      actors: %{alice: alice, bob: bob},
      groups: %{admins: admins, users: users},
      scopes: %{documents: documents, settings: settings},
      test_node: stored_test_node
    }

    # Ensure we clean up after the test
    on_exit(fn -> 
      try do
        Store.stop(store_name)
      catch
        :exit, _ -> :ok
      end
    end)

    # Return the context
    {:ok, context}
  end

  describe "Actor entity" do
    test "actor creation and fields", %{policy: policy, store_name: store_name} do
      {:ok, charlie} = Access.create_actor(store_name, policy.id, %{id: "charlie", name: "Charlie"})
      assert charlie.id == "charlie"
      assert charlie.data.name == "Charlie"
      assert charlie.graph_id == policy.id
    end

    test "actor permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      scopes: %{documents: documents}
    } do
      # Grant read permission to Alice on documents
      Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Check permissions
      assert Access.has_permission?(store_name, documents.id, alice.id, :read)
      refute Access.has_permission?(store_name, documents.id, alice.id, :write)
    end

    test "checking permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      scopes: %{documents: documents},
      groups: %{admins: admins}
    } do
      # Add actor to group
      Access.add_to_group(store_name, policy.id, alice.id, admins.id)

      # Check membership
      assert Access.is_member?(store_name, alice.id, admins.id)
      assert not Access.is_member?(store_name, bob.id, admins.id)

      # Remove actor from group
      Access.remove_from_group(store_name, policy.id, alice.id, admins.id)

      # Check membership again
      assert not Access.is_member?(store_name, alice.id, admins.id)
    end

    test "group management", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins}
    } do
      # Add actor to group
      Access.add_to_group(store_name, policy.id, alice.id, admins.id)

      # Verify membership
      assert Access.is_member?(store_name, alice.id, admins.id)

      # Remove actor from group
      Access.remove_from_group(store_name, policy.id, alice.id, admins.id)

      # Verify removal
      assert not Access.is_member?(store_name, alice.id, admins.id)
    end

    test "authorization", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      scopes: %{documents: documents},
      test_node: test_node
    } do
      # Grant permission
      # Node binding happens in setup
      Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Check authorization
      assert Access.authorize?(store_name, alice.id, :read, test_node.id)
      refute Access.authorize?(store_name, alice.id, :write, test_node.id)
    end
  end

  describe "Scope entity" do
    test "scope creation and fields", %{policy: policy, store_name: store_name} do
      {:ok, reports} = Access.create_scope(store_name, policy.id, %{id: "reports", name: "Reports"})
      assert reports.id == "reports"
      assert reports.data.name == "Reports"
      assert reports.graph_id == policy.id
    end

    test "scope permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins},
      scopes: %{settings: settings}
    } do
      # Grant permission to Alice directly
      Access.grant_permission(store_name, policy.id, settings.id, alice.id, %{read: true})
      # Grant permission to admins group
      Access.grant_permission(store_name, policy.id, settings.id, admins.id, %{write: true})

      # List permissions on the scope
      {:ok, permissions} = Access.list_scope_permissions(store_name, settings.id)
      assert length(permissions) == 2

      # Find Alice's permission
      alice_perm = Enum.find(permissions, fn p -> p.target_id == alice.id end)
      assert alice_perm != nil
      assert alice_perm.target_type == "actor"
      assert alice_perm.permissions.read == true

      # Find admins group's permission
      admin_perm = Enum.find(permissions, fn p -> p.target_id == admins.id end)
      assert admin_perm != nil
      assert admin_perm.target_type == "group"
      assert admin_perm.permissions.write == true
    end

    test "granting and revoking permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{bob: bob},
      scopes: %{documents: documents}
    } do
      # Grant permission
      {:ok, _perm} = Access.grant_permission(store_name, policy.id, documents.id, bob.id, %{read: true, write: true})

      # Check permission
      assert Access.has_permission?(store_name, documents.id, bob.id, :read)

      # Revoke permission
      :ok = Access.revoke_permission(store_name, policy.id, documents.id, bob.id)

      # Verify revocation
      refute Access.has_permission?(store_name, documents.id, bob.id, :read)
    end

    test "binding nodes to scope", %{
      store_name: store_name, # Keep for Store.insert
      policy: policy,
      scopes: %{documents: documents},
      test_node: test_node
    } do
      # Create another node
      node2 = Node.new(%{id: "node2", data: %{info: "more data"}})
      {:ok, stored_node2} = Store.insert(store_name, Node, node2)

      # Bind the second node
      {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, documents.id, stored_node2.id)

      # List nodes in scope
      {:ok, nodes} = Access.list_scope_nodes(store_name, documents.id)
      assert length(nodes) == 2
      assert Enum.any?(nodes, &(&1.node_id == test_node.id))
      assert Enum.any?(nodes, &(&1.node_id == stored_node2.id))

      # Unbind node
      :ok = Access.unbind_scope_from_node(store_name, policy.id, documents.id, test_node.id)

      # List nodes again
      {:ok, nodes_after_unbind} = Access.list_scope_nodes(store_name, documents.id)
      assert length(nodes_after_unbind) == 1
    end
  end

  describe "Integration between Actor and Scope" do
    test "authorization flow", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins},
      scopes: %{documents: documents},
      test_node: test_node
    } do
      # Actor joins group
      {:ok, _} = Access.add_to_group(store_name, policy.id, alice.id, admins.id)
      # Group gets permission on scope
      Access.grant_permission(store_name, policy.id, documents.id, admins.id, %{read: true})
      # Node is bound to scope (already done in setup)
      # {:ok, _} = Access.bind_scope_to_node(policy.id, documents.id, test_node.id) # Redundant? Already bound in setup

      # Check authorization
      assert Access.authorize?(store_name, alice.id, :read, test_node.id)
      # Check lack of write permission
      refute Access.authorize?(store_name, alice.id, :write, test_node.id)
    end
  end
end
