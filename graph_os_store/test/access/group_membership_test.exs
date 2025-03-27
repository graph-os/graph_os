defmodule GraphOS.Access.GroupMembershipTest do
  use ExUnit.Case

  alias GraphOS.Access
  alias GraphOS.Access.{Group, Membership}

  setup do
    # Clean store state before each test
    GraphOS.Test.Support.GraphFactory.reset_store()

    # Create a test policy
    {:ok, policy} = Access.create_policy("group_membership_test_policy")

    # Create test actors
    {:ok, alice} = Access.create_actor(policy.id, %{id: "alice", name: "Alice"})
    {:ok, bob} = Access.create_actor(policy.id, %{id: "bob", name: "Bob"})
    {:ok, charlie} = Access.create_actor(policy.id, %{id: "charlie", name: "Charlie"})

    # Create test groups
    {:ok, admins} = Access.create_group(policy.id, %{id: "admins", name: "Administrators", description: "Admin users"})
    {:ok, users} = Access.create_group(policy.id, %{id: "users", name: "Regular Users", description: "Standard users"})

    # Create test scopes
    {:ok, documents} = Access.create_scope(policy.id, %{id: "documents", name: "Documents"})
    {:ok, settings} = Access.create_scope(policy.id, %{id: "settings", name: "System Settings"})

    %{
      policy: policy,
      alice: alice,
      bob: bob,
      charlie: charlie,
      admins: admins,
      users: users,
      documents: documents,
      settings: settings
    }
  end

  describe "Group entity" do
    test "group creation and fields", %{admins: admins} do
      assert admins.id == "admins"
      assert admins.data.name == "Administrators"
      assert admins.data.description == "Admin users"
    end

    test "group permissions", %{policy: policy, admins: admins, settings: settings} do
      # Grant permissions to the admins group
      {:ok, _permission} = Access.grant_permission(policy.id, settings.id, admins.id, %{read: true, write: true})

      # Get permissions granted to the group
      {:ok, permissions} = Group.permissions(admins.id)

      # Should have 1 permission on settings
      assert length(permissions) == 1

      # Check permission details
      scope_perm = Enum.at(permissions, 0)
      assert scope_perm.scope_id == settings.id
      assert scope_perm.permissions.read == true
      assert scope_perm.permissions.write == true
    end

    test "adding and removing members", %{policy: policy, alice: alice, admins: admins} do
      # Add Alice to the admins group
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)

      # Check if Alice is a member
      assert Group.has_member?(admins.id, alice.id) == true

      # Remove Alice - using correct signature
      :ok = Group.remove_member(admins.id, alice.id)

      # Check if Alice is still a member after removal
      assert Group.has_member?(admins.id, alice.id) == false
    end

    test "checking group permissions", %{policy: policy, admins: admins, settings: settings} do
      # Check before granting permission
      assert Group.has_permission?(admins.id, settings.id, :write) == false

      # Grant permission
      {:ok, _} = Access.grant_permission(policy.id, settings.id, admins.id, %{write: true})

      # Check again after granting
      assert Group.has_permission?(admins.id, settings.id, :write) == true
    end

    test "listing group members", %{policy: policy, alice: alice, bob: bob, admins: admins} do
      # Add both Alice and Bob to the group
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)
      {:ok, _} = Access.add_to_group(policy.id, bob.id, admins.id)

      # Get all members of the group
      {:ok, members} = Group.members(admins.id)

      # Should have 2 members (Alice and Bob)
      assert length(members) == 2
      assert Enum.any?(members, fn m -> m.actor_id == alice.id end)
      assert Enum.any?(members, fn m -> m.actor_id == bob.id end)
    end
  end

  describe "Membership entity" do
    test "membership creation", %{policy: policy, alice: alice, admins: admins} do
      # Create new membership
      {:ok, membership} = Membership.create(policy.id, alice.id, admins.id)

      assert membership.source == alice.id
      assert membership.target == admins.id
      assert Map.has_key?(membership.data, :joined_at)
    end

    test "finding memberships by actor", %{policy: policy, alice: alice, admins: admins, users: users} do
      # Add Alice to both groups
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)
      {:ok, _} = Access.add_to_group(policy.id, alice.id, users.id)

      # Find all memberships for Alice
      {:ok, memberships} = Membership.find_by_actor(alice.id)

      # Alice should be in 2 groups
      assert length(memberships) == 2
      assert Enum.any?(memberships, fn m -> m.target == admins.id end)
      assert Enum.any?(memberships, fn m -> m.target == users.id end)
    end

    test "finding memberships by group", %{policy: policy, alice: alice, bob: bob, admins: admins} do
      # Add both Alice and Bob to admins
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)
      {:ok, _} = Access.add_to_group(policy.id, bob.id, admins.id)

      # Find all memberships for the admins group
      {:ok, memberships} = Membership.find_by_group(admins.id)

      # Should have 2 members (Alice and Bob)
      assert length(memberships) == 2
      assert Enum.any?(memberships, fn m -> m.source == alice.id end)
      assert Enum.any?(memberships, fn m -> m.source == bob.id end)
    end

    test "checking membership existence", %{policy: policy, alice: alice, bob: bob, admins: admins} do
      # Add Alice to the group
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)

      # Check if Alice is a member
      assert Membership.exists?(alice.id, admins.id) == true

      # Check if Bob is a member (should be false)
      assert Membership.exists?(bob.id, admins.id) == false
    end

    test "removing membership", %{policy: policy, alice: alice, admins: admins} do
      # Add Alice to the group
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)

      # Check Alice is a member
      assert Membership.exists?(alice.id, admins.id) == true

      # Remove membership - using correct signature
      :ok = Membership.remove(alice.id, admins.id)

      # Verify Alice is no longer a member
      assert Membership.exists?(alice.id, admins.id) == false
    end
  end

  describe "Inheritance and Group Hierarchies" do
    test "actor inherits permissions from multiple groups", %{policy: policy, alice: alice, admins: admins, users: users, documents: documents, settings: settings} do
      # Add Alice to both groups
      {:ok, _} = Access.add_to_group(policy.id, alice.id, admins.id)
      {:ok, _} = Access.add_to_group(policy.id, alice.id, users.id)

      # Grant different permissions to each group
      # - Admins: Read/Write on settings
      # - Users: Read on documents
      {:ok, _} = Access.grant_permission(policy.id, settings.id, admins.id, %{read: true, write: true})
      {:ok, _} = Access.grant_permission(policy.id, documents.id, users.id, %{read: true})

      # Check Alice's permissions (should inherit from both groups)
      {:ok, permissions} = Access.list_actor_permissions(alice.id)

      # Should have 2 permissions total (one from each group)
      assert length(permissions) == 2

      # Check settings permission (from admins)
      settings_perm = Enum.find(permissions, fn p -> p.scope_id == settings.id end)
      assert settings_perm != nil
      assert settings_perm.permissions.read == true
      assert settings_perm.permissions.write == true
      assert settings_perm.via_group == admins.id

      # Check documents permission (from users)
      documents_perm = Enum.find(permissions, fn p -> p.scope_id == documents.id end)
      assert documents_perm != nil
      assert documents_perm.permissions.read == true
      assert documents_perm.via_group == users.id
    end
  end
end
