defmodule GraphOS.AccessTest do
  use ExUnit.Case, async: false # Set to false for consistency with other test modules

  alias GraphOS.Access
  alias GraphOS.Store
  alias GraphOS.Entity.Node
  alias GraphOS.Store.Adapter.ETS

  setup do
    # Generate a unique store name for this test
    store_name = :"access_test_store_#{:erlang.unique_integer([:positive])}"

    # Start the store for this test
    {:ok, _pid} = Store.start_link(name: store_name, adapter: ETS)

    # Ensure store is stopped on exit
    on_exit(fn ->
      try do
        Store.stop(store_name)
      catch
        :exit, _ -> nil
      end
    end)

    # Create a test policy for all tests within this store
    # Use store_name explicitly for all operations
    {:ok, policy} = Access.create_policy(store_name, "test_policy")

    # Create test actors
    {:ok, alice} = Access.create_actor(store_name, policy.id, %{id: "alice", name: "Alice"})
    {:ok, bob} = Access.create_actor(store_name, policy.id, %{id: "bob", name: "Bob"})

    # Create test group
    {:ok, admins} = Access.create_group(store_name, policy.id, %{id: "admins", name: "Administrators"})

    # Create test scopes
    {:ok, documents} = Access.create_scope(store_name, policy.id, %{id: "documents", name: "Documents"})
    {:ok, settings} = Access.create_scope(store_name, policy.id, %{id: "settings", name: "System Settings"})

    # Return context map for tests
    {:ok,
     %{
       store_name: store_name,
       policy: policy,
       actors: %{alice: alice, bob: bob},
       groups: %{admins: admins},
       scopes: %{documents: documents, settings: settings}
     }}
  end

  describe "basic access control functionality" do
    test "creating actors, groups and scopes", %{policy: policy, store_name: store_name} do
      {:ok, charlie} = Access.create_actor(store_name, policy.id, %{id: "charlie", name: "Charlie"})
      assert charlie.id == "charlie"
      assert charlie.data.name == "Charlie"

      {:ok, users} = Access.create_group(store_name, policy.id, %{id: "users", name: "Regular Users"})
      assert users.id == "users"
      assert users.data.name == "Regular Users"

      {:ok, api_keys} = Access.create_scope(store_name, policy.id, %{id: "api_keys", name: "API Keys"})
      assert api_keys.id == "api_keys"
      assert api_keys.data.name == "API Keys"
    end

    test "granting permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      scopes: %{documents: documents}
    } do
      # Grant read and write permissions to Alice on documents
      {:ok, permission} =
        Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{
          read: true,
          write: true
        })

      assert permission.source == documents.id
      assert permission.target == alice.id
      assert permission.data.read
      assert permission.data.write
      # Use Map.get to safely check for execute permission that might not exist
      refute Map.get(permission.data, :execute)
      # Use Map.get to safely check for destroy permission that might not exist
      refute Map.get(permission.data, :destroy)
    end

    test "checking permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      scopes: %{documents: documents}
    } do
      # Grant only read permission to Alice
      {:ok, _} = Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Alice should have read permission but not write
      assert Access.has_permission?(store_name, documents.id, alice.id, :read)
      refute Access.has_permission?(store_name, documents.id, alice.id, :write)

      # Bob should not have any permissions
      refute Access.has_permission?(store_name, documents.id, bob.id, :read)
      refute Access.has_permission?(store_name, documents.id, bob.id, :write)
    end
  end

  describe "group-based permissions" do
    test "adding actors to groups", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins}
    } do
      {:ok, membership} = Access.add_to_group(store_name, policy.id, alice.id, admins.id)

      assert membership.source == alice.id
      assert membership.target == admins.id
      assert Map.has_key?(membership.data, :joined_at)
    end

    test "inheriting permissions from groups", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      groups: %{admins: admins},
      scopes: %{settings: settings}
    } do
      # Add Alice to the admins group
      {:ok, _} = Access.add_to_group(store_name, policy.id, alice.id, admins.id)

      # Grant permissions to the admins group
      {:ok, _} =
        Access.grant_permission(store_name, policy.id, settings.id, admins.id, %{
          read: true,
          write: true
        })

      # Alice should inherit permissions from the admins group
      assert Access.has_permission?(store_name, settings.id, alice.id, :read)
      assert Access.has_permission?(store_name, settings.id, alice.id, :write)

      # Bob is not in the admins group, so should not have permissions
      refute Access.has_permission?(store_name, settings.id, bob.id, :read)
      refute Access.has_permission?(store_name, settings.id, bob.id, :write)
    end
  end

  describe "scope binding and authorization" do
    test "authorization checks on nodes", %{
      store_name: store_name,
      policy: policy,
      actors: %{alice: alice, bob: bob},
      scopes: %{documents: documents}
    } do
      # Create a test document node
      document_node = Node.new(%{id: "doc1", data: %{title: "Important Document"}})
      # Use store_name for direct Store call
      {:ok, stored_doc} = Store.insert(store_name, Node, document_node)

      # Bind the document to the documents scope
      {:ok, binding} = Access.bind_scope_to_node(store_name, policy.id, documents.id, stored_doc.id)

      assert binding.source == documents.id
      assert binding.target == stored_doc.id
      assert Map.has_key?(binding.data, :bound_at)

      # Grant read permission to Alice
      {:ok, _} = Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Check authorization
      assert Access.authorize?(store_name, alice.id, :read, stored_doc.id)
      refute Access.authorize?(store_name, alice.id, :write, stored_doc.id)
      refute Access.authorize?(store_name, bob.id, :read, stored_doc.id)
    end
  end

  describe "listing and querying" do
    test "listing actor permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins},
      scopes: %{documents: documents, settings: settings}
    } do
      # Grant direct permission to Alice on documents
      {:ok, _} = Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Add Alice to admins group
      {:ok, _} = Access.add_to_group(store_name, policy.id, alice.id, admins.id)

      # Grant permission to admins group on settings
      {:ok, _} =
        Access.grant_permission(store_name, policy.id, settings.id, admins.id, %{
          read: true,
          write: true
        })

      # List all permissions (direct and inherited)
      {:ok, permissions} = Access.list_actor_permissions(store_name, alice.id)

      # Should find both permissions (direct and via group)
      assert length(permissions) == 2

      # Check the direct permission on documents
      doc_perm = Enum.find(permissions, fn p -> p.scope_id == documents.id end)
      assert doc_perm != nil
      assert doc_perm.permissions.read

      # Check the group permission on settings (should include group info)
      settings_perm = Enum.find(permissions, fn p -> p.scope_id == settings.id end)
      assert settings_perm != nil
      assert settings_perm.permissions.read
      assert settings_perm.permissions.write
      assert settings_perm.via_group == admins.id
    end

    test "listing scope permissions", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{admins: admins},
      scopes: %{documents: documents}
    } do
      # Grant permission to Alice
      {:ok, _} = Access.grant_permission(store_name, policy.id, documents.id, alice.id, %{read: true})

      # Grant permission to admins group
      {:ok, _} =
        Access.grant_permission(store_name, policy.id, documents.id, admins.id, %{
          read: true,
          write: true
        })

      # List all permissions on the documents scope
      {:ok, permissions} = Access.list_scope_permissions(store_name, documents.id)

      # Should find permissions for both Alice and admins group
      assert length(permissions) == 2

      # Check for Alice's permission
      alice_perm = Enum.find(permissions, fn p -> p.target_id == alice.id end)
      assert alice_perm != nil
      assert alice_perm.target_type == "actor"
      assert alice_perm.permissions.read

      # Check for admins group permission
      admins_perm = Enum.find(permissions, fn p -> p.target_id == admins.id end)
      assert admins_perm != nil
      assert admins_perm.target_type == "group"
      assert admins_perm.permissions.read
      assert admins_perm.permissions.write
    end

    test "listing scope nodes", %{store_name: store_name, policy: policy, scopes: %{documents: documents}} do
      # Create multiple document nodes
      doc1 = Node.new(%{id: "doc1", data: %{title: "Document 1"}})
      doc2 = Node.new(%{id: "doc2", data: %{title: "Document 2"}})
      # Use store_name for direct Store calls
      {:ok, stored_doc1} = Store.insert(store_name, Node, doc1)
      {:ok, stored_doc2} = Store.insert(store_name, Node, doc2)

      # Bind both documents to the documents scope
      {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, documents.id, stored_doc1.id)
      {:ok, _} = Access.bind_scope_to_node(store_name, policy.id, documents.id, stored_doc2.id)

      # List all nodes in the documents scope
      {:ok, nodes} = Access.list_scope_nodes(store_name, documents.id)

      # Should find both documents
      assert length(nodes) == 2
      assert Enum.any?(nodes, fn n -> n.node_id == "doc1" end)
      assert Enum.any?(nodes, fn n -> n.node_id == "doc2" end)
    end
  end

  # Removed MockAccess module as we are now testing the actual Access functions
end
