defmodule GraphOS.Access.PermissionTest do
  use ExUnit.Case, async: true

  alias GraphOS.Access
  alias GraphOS.Access.{Policy, Actor, Scope, Permission}
  alias GraphOS.Store

  setup do
    # Start the store
    {:ok, _pid} = Store.start()

    # Create a test policy
    {:ok, policy} = Access.create_policy("test_policy")

    # Create test actors
    {:ok, user} = Access.create_actor(policy.id, %{id: "user_1", name: "Test User"})
    {:ok, admin} = Access.create_actor(policy.id, %{id: "admin_1", name: "Admin User"})

    # Create test scopes
    {:ok, resource} = Access.create_scope(policy.id, %{id: "resource_1"})
    {:ok, system} = Access.create_scope(policy.id, %{id: "system_1"})

    # Create some permissions
    {:ok, user_perm} = Access.grant_permission(
      policy.id, resource.id, user.id, %{read: true, write: false}
    )

    {:ok, admin_perm} = Access.grant_permission(
      policy.id, resource.id, admin.id, %{read: true, write: true, execute: true}
    )

    {:ok, admin_system_perm} = Access.grant_permission(
      policy.id, system.id, admin.id, %{read: true, execute: true}
    )

    on_exit(fn ->
      :ok = Store.stop()
    end)

    {:ok, %{
      policy: policy,
      actors: %{user: user, admin: admin},
      scopes: %{resource: resource, system: system},
      permissions: %{
        user_perm: user_perm,
        admin_perm: admin_perm,
        admin_system_perm: admin_system_perm
      }
    }}
  end

  describe "has_permission?/3" do
    test "correctly checks if an actor has a specific permission", %{
      actors: %{user: user, admin: admin},
      scopes: %{resource: resource, system: system}
    } do
      # User should have read access to resource but not write
      assert Access.has_permission?(resource.id, user.id, :read) == true
      assert Access.has_permission?(resource.id, user.id, :write) == false

      # Admin should have read, write, and execute access to resource
      assert Access.has_permission?(resource.id, admin.id, :read) == true
      assert Access.has_permission?(resource.id, admin.id, :write) == true
      assert Access.has_permission?(resource.id, admin.id, :execute) == true

      # Admin should have read and execute access to system, but not write
      assert Access.has_permission?(system.id, admin.id, :read) == true
      assert Access.has_permission?(system.id, admin.id, :execute) == true
      assert Access.has_permission?(system.id, admin.id, :write) == false

      # User should not have any access to system
      assert Access.has_permission?(system.id, user.id, :read) == false
      assert Access.has_permission?(system.id, user.id, :write) == false
      assert Access.has_permission?(system.id, user.id, :execute) == false
    end
  end

  describe "Actor.permissions/1" do
    test "lists all permissions for an actor", %{
      actors: %{admin: admin}
    } do
      {:ok, permissions} = Actor.permissions(admin.id)

      assert length(permissions) == 2
      assert Enum.any?(permissions, fn p -> p.scope_id == "resource_1" end)
      assert Enum.any?(permissions, fn p -> p.scope_id == "system_1" end)
    end
  end

  describe "Scope.permissions/1" do
    test "lists all permissions on a scope", %{
      scopes: %{resource: resource}
    } do
      {:ok, permissions} = Scope.permissions(resource.id)

      assert length(permissions) == 2
      assert Enum.any?(permissions, fn p -> p.actor_id == "user_1" end)
      assert Enum.any?(permissions, fn p -> p.actor_id == "admin_1" end)
    end
  end

  describe "Permission.update/2" do
    test "updates permission settings", %{
      permissions: %{user_perm: user_perm}
    } do
      # Update the permission to add write access
      {:ok, updated_perm} = Permission.update(user_perm.id, %{write: true})

      # Verify the update worked
      assert updated_perm.data.write == true
      assert updated_perm.data.read == true
    end
  end

  describe "Permission.revoke/1" do
    test "revokes a permission by deleting the edge", %{
      permissions: %{user_perm: user_perm},
      actors: %{user: user},
      scopes: %{resource: resource}
    } do
      # Initially user has read permission
      assert Access.has_permission?(resource.id, user.id, :read) == true

      # Revoke the permission
      :ok = Permission.revoke(user_perm.id)

      # User should no longer have read permission
      assert Access.has_permission?(resource.id, user.id, :read) == false
    end
  end

  describe "Policy.verify_permission?/3" do
    test "correctly verifies permissions", %{
      actors: %{user: user, admin: admin},
      scopes: %{resource: resource}
    } do
      # User has read but not write
      assert Policy.verify_permission?(resource.id, user.id, :read) == true
      assert Policy.verify_permission?(resource.id, user.id, :write) == false

      # Admin has both read and write
      assert Policy.verify_permission?(resource.id, admin.id, :read) == true
      assert Policy.verify_permission?(resource.id, admin.id, :write) == true
    end
  end

  describe "integration" do
    test "complete permission flow", %{policy: policy} do
      # Create a new actor, scope, and permission
      {:ok, new_user} = Policy.add_actor(policy.id, %{id: "new_user", name: "New User"})
      {:ok, new_resource} = Policy.add_scope(policy.id, %{id: "new_resource"})

      # Grant limited permissions
      {:ok, _perm} = Scope.grant_to(policy.id, new_resource.id, new_user.id, %{read: true})

      # Check that permissions work
      assert Actor.has_permission?(new_user.id, new_resource.id, :read) == true
      assert Actor.has_permission?(new_user.id, new_resource.id, :write) == false

      # List the permissions
      {:ok, actor_perms} = Actor.permissions(new_user.id)
      assert length(actor_perms) == 1
      assert hd(actor_perms).scope_id == new_resource.id
      assert hd(actor_perms).permissions.read == true

      # Get the permission ID
      {:ok, [perm]} = Permission.find_between(new_resource.id, new_user.id)

      # Update the permission
      {:ok, updated_perm} = Permission.update(perm.id, %{write: true})
      assert updated_perm.data.write == true

      # Verify the update took effect
      assert Actor.has_permission?(new_user.id, new_resource.id, :write) == true

      # Revoke the permission
      :ok = Permission.revoke(perm.id)

      # Verify permissions are gone
      assert Actor.has_permission?(new_user.id, new_resource.id, :read) == false
    end
  end
end
