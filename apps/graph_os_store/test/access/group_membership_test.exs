defmodule GraphOS.Access.GroupMembershipTest do
  use ExUnit.Case, async: false

  alias GraphOS.Access
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS

  setup do
    # Generate a unique store name for this test
    store_name = String.to_atom("group_membership_test_store_#{System.unique_integer([:positive, :monotonic])}")

    # Start the store for this test
    {:ok, pid} = Store.start_link(name: store_name, adapter: ETS)

    # Ensure store is stopped on exit
    on_exit(fn -> 
      try do
        if Process.alive?(pid) do
          Store.stop(store_name)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    # Create a test policy
    {:ok, policy} = Access.create_policy(store_name, "test_policy")

    # Create test actors
    {:ok, alice} = Access.create_actor(store_name, policy.id, %{id: "alice", name: "Alice"})
    {:ok, bob} = Access.create_actor(store_name, policy.id, %{id: "bob", name: "Bob"})

    # Create test groups
    {:ok, developers} = Access.create_group(store_name, policy.id, %{id: "devs", name: "Developers"})
    {:ok, managers} = Access.create_group(store_name, policy.id, %{id: "mgrs", name: "Managers"})

    # Create a scope for permission tests
    {:ok, project_scope} = Access.create_scope(store_name, policy.id, %{id: "project_a", name: "Project A"})

    # Add alice to developers group initially
    {:ok, _} = Access.add_to_group(store_name, policy.id, alice.id, developers.id)

    # Return context map
    {:ok,
     %{
       store_name: store_name,
       policy: policy,
       actors: %{alice: alice, bob: bob},
       groups: %{devs: developers, mgrs: managers},
       scope: project_scope,
       project_scope: project_scope
     }}
  end

  describe "Group entity" do
    test "group creation and fields", %{policy: policy, store_name: store_name} do
      {:ok, qa_team} = Access.create_group(store_name, policy.id, %{id: "qa", name: "QA Team"})
      assert qa_team.id == "qa"
      assert qa_team.data.name == "QA Team"
      assert qa_team.graph_id == policy.id
    end

    test "group permissions", %{
      policy: policy,
      store_name: store_name,
      groups: %{devs: developers},
      scope: scope
    } do
      # Grant permissions to the group
      {:ok, permission} =
        Access.grant_permission(store_name, policy.id, scope.id, developers.id, %{
          read: true,
          write: true,
          execute: true
        })

      assert permission.source == scope.id
      assert permission.target == developers.id
      assert permission.data.read == true
      assert permission.data.write == true
      assert permission.data.execute == true

      # Check group permissions
      assert Access.has_permission?(store_name, scope.id, developers.id, :read)
      assert Access.has_permission?(store_name, scope.id, developers.id, :write)
      assert Access.has_permission?(store_name, scope.id, developers.id, :execute)
    end

    test "adding and removing members", %{
      policy: policy,
      store_name: store_name,
      actors: %{bob: bob},
      groups: %{devs: developers}
    } do
      # Add bob to developers
      {:ok, _} = Access.add_to_group(store_name, policy.id, bob.id, developers.id)

      # Verify membership
      assert Access.is_member?(store_name, bob.id, developers.id)

      # Remove bob from developers
      {:ok, _} = Access.remove_from_group(store_name, policy.id, bob.id, developers.id)

      # Verify removal
      refute Access.is_member?(store_name, bob.id, developers.id)
    end

    test "checking group permissions", %{
      policy: policy,
      store_name: store_name,
      groups: %{devs: developers},
      project_scope: project_scope
    } do
      # Grant permissions
      Access.grant_permission(store_name, policy.id, project_scope.id, developers.id, %{read: true})

      # Check group permissions
      assert Access.has_permission?(store_name, project_scope.id, developers.id, :read)
      refute Access.has_permission?(store_name, project_scope.id, developers.id, :write)
      refute Access.has_permission?(store_name, project_scope.id, developers.id, :execute)
    end

    test "listing group members", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      groups: %{devs: developers}
    } do
      # Add bob as well (alice added in setup)
      Access.add_to_group(store_name, policy.id, bob.id, developers.id)

      # List members
      {:ok, members} = Access.list_group_members(store_name, developers.id)

      assert length(members) == 2
      assert Enum.any?(members, &(&1.actor_id == alice.id))
      assert Enum.any?(members, &(&1.actor_id == bob.id))
    end
  end

  describe "Membership entity" do
    test "membership creation", %{
      policy: policy,
      store_name: store_name,
      actors: %{bob: bob},
      groups: %{mgrs: managers}
    } do
      # Create membership directly (this tests if add_to_group works)
      {:ok, membership} = Access.add_to_group(store_name, policy.id, bob.id, managers.id)

      assert membership.source == bob.id
      assert membership.target == managers.id
    end

    test "finding memberships by actor", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{devs: developers, mgrs: managers}
    } do
      # Add alice to managers as well (already in developers from setup)
      Access.add_to_group(store_name, policy.id, alice.id, managers.id)

      # List actor groups/memberships
      {:ok, memberships} = Access.list_actor_groups(store_name, alice.id)

      assert length(memberships) == 2
      assert Enum.any?(memberships, &(&1.group_id == developers.id))
      assert Enum.any?(memberships, &(&1.group_id == managers.id))
    end

    test "finding memberships by group", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      groups: %{devs: developers}
    } do
      # Add bob to developers
      Access.add_to_group(store_name, policy.id, bob.id, developers.id)

      # List group members
      {:ok, members} = Access.list_group_members(store_name, developers.id)

      assert length(members) == 2
      assert Enum.any?(members, &(&1.actor_id == alice.id))
      assert Enum.any?(members, &(&1.actor_id == bob.id))
    end

    test "checking membership existence", %{
      store_name: store_name,
      actors: %{alice: alice, bob: bob},
      groups: %{devs: developers}
    } do
      # Alice is a member from setup
      assert Access.is_member?(store_name, alice.id, developers.id)
      # Bob is not (initially)
      refute Access.is_member?(store_name, bob.id, developers.id)
    end

    test "removing membership", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{devs: developers}
    } do
      # Verify initial membership
      assert Access.is_member?(store_name, alice.id, developers.id)

      # Remove membership
      {:ok, _} = Access.remove_from_group(store_name, policy.id, alice.id, developers.id)

      # Verify removal
      refute Access.is_member?(store_name, alice.id, developers.id)
    end
  end

  describe "Inheritance and Group Hierarchies" do
    test "actor inherits permissions from multiple groups", %{
      policy: policy,
      store_name: store_name,
      actors: %{alice: alice},
      groups: %{devs: developers, mgrs: managers},
      project_scope: project_scope
    } do
      # Grant devs read, mgrs write
      Access.grant_permission(store_name, policy.id, project_scope.id, developers.id, %{read: true})
      Access.grant_permission(store_name, policy.id, project_scope.id, managers.id, %{write: true})

      # Add alice to managers (already in developers)
      Access.add_to_group(store_name, policy.id, alice.id, managers.id)

      # Alice should have both read (from devs) and write (from mgrs)
      assert Access.has_permission?(store_name, project_scope.id, alice.id, :read)
      assert Access.has_permission?(store_name, project_scope.id, alice.id, :write)
      refute Access.has_permission?(store_name, project_scope.id, alice.id, :execute)
    end

    # Note: True hierarchical groups (groups within groups) are not directly supported by this model.
    # That would require a separate feature implementation.
  end
end
