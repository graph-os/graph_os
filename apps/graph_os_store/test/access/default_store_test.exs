defmodule GraphOS.Access.DefaultStoreTest do
  use ExUnit.Case, async: false

  alias GraphOS.Access
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS

  setup do
    # Initialize the default store for testing the 2-arity API functions
    store_name = :default
    {:ok, _pid} = Store.start_link(name: store_name, adapter: ETS)

    # Ensure we clean up after the test
    on_exit(fn -> 
      try do
        Store.stop(store_name)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, %{store_name: store_name}}
  end

  describe "Default store API functions" do
    test "can create and use a policy with the default store", %{store_name: store_name} do
      # Test using 2-arity functions that implicitly use :default store
      {:ok, policy} = Access.create_policy("test_default_policy")
      assert policy.name == "test_default_policy"
      
      # Create actor using 2-arity function
      {:ok, alice} = Access.create_actor(policy.id, %{id: "alice", name: "Alice"})
      assert alice.id == "alice"
      
      # Create group using 2-arity function
      {:ok, admins} = Access.create_group(policy.id, %{id: "admins", name: "Administrators"})
      assert admins.id == "admins"
      
      # Create scope using 2-arity function
      {:ok, documents} = Access.create_scope(policy.id, %{id: "documents", name: "Documents"})
      assert documents.id == "documents"
      
      # Add actor to group using 2-arity function
      {:ok, _membership} = Access.add_to_group(policy.id, alice.id, admins.id)
      
      # Grant permission using 2-arity function
      {:ok, _perm} = Access.grant_permission(policy.id, documents.id, alice.id, %{read: true})
      
      # Check permission using 3-arity function (explicitly providing store_name)
      assert Access.has_permission?(store_name, documents.id, alice.id, :read)
      refute Access.has_permission?(store_name, documents.id, alice.id, :write)
    end
  end
end
