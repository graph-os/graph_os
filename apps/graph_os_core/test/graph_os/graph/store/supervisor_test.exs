defmodule GraphOS.Graph.Store.SupervisorTest do
  use ExUnit.Case, async: false
  @moduletag :code_graph
  
  alias GraphOS.Graph.Store.Supervisor, as: StoreSupervisor
  alias GraphOS.Graph.Store.ETS
  
  setup do
    # Start the registry if it doesn't exist yet
    start_registry_and_supervisor()
    
    # Generate a unique identifier for this test run
    test_id = System.unique_integer([:positive])
    {:ok, test_id: test_id}
  end
  
  describe "supervisor operations" do
    test "starts a store process", %{test_id: test_id} do
      store_name = "test_store_#{test_id}"
      
      # Start a new store
      {:ok, pid} = StoreSupervisor.start_store(
        store_name,
        ETS,
        [name: store_name]
      )
      
      # Verify the store process is running
      assert Process.alive?(pid)
      
      # Verify it's registered in the registry
      assert [{^pid, _}] = Registry.lookup(GraphOS.Graph.StoreRegistry, store_name)
    end
    
    test "can start multiple stores", %{test_id: test_id} do
      # Start three different stores
      store_names = for i <- 1..3 do
        name = "multi_store_#{test_id}_#{i}"
        {:ok, _pid} = StoreSupervisor.start_store(name, ETS, [name: name])
        name
      end
      
      # Verify all stores are registered
      Enum.each(store_names, fn name ->
        assert [{pid, _}] = Registry.lookup(GraphOS.Graph.StoreRegistry, name)
        assert Process.alive?(pid)
      end)
    end
    
    test "restarts a failed store", %{test_id: test_id} do
      store_name = "restart_store_#{test_id}"
      
      # Start a new store
      {:ok, pid} = StoreSupervisor.start_store(
        store_name,
        ETS,
        [name: store_name]
      )
      
      # Kill the process to test supervisor restart
      Process.exit(pid, :kill)
      
      # Wait a bit for the supervisor to restart the process
      :timer.sleep(100)
      
      # Verify a new process is running with the same name
      assert [{new_pid, _}] = Registry.lookup(GraphOS.Graph.StoreRegistry, store_name)
      assert Process.alive?(new_pid)
      assert new_pid != pid, "Expected a new process to be started"
    end
  end
  
  # Helper functions
  
  defp start_registry_and_supervisor do
    # Start the registry
    case Registry.start_link(keys: :unique, name: GraphOS.Graph.StoreRegistry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    # Start the supervisor
    case DynamicSupervisor.start_link(name: GraphOS.Graph.StoreSupervisor, strategy: :one_for_one) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end
