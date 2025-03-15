defmodule GraphOS.Graph.Store.CrossQueryTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph
  
  alias GraphOS.Graph.Store.CrossQuery
  alias GraphOS.Graph.Store.Server
  
  # We'll need to register our test stores in the registry manually
  setup do
    # Start the Registry if it doesn't exist yet
    start_registry()
    
    # Generate a unique identifier for this test run
    test_id = System.unique_integer([:positive])
    {:ok, test_id: test_id}
  end
  
  describe "comparing stores" do
    setup %{test_id: test_id} do
      # Create two stores with different content for comparison
      {:ok, store1} = create_test_store("store1_#{test_id}")
      {:ok, store2} = create_test_store("store2_#{test_id}")
      
      # Add some common nodes to both stores
      common_nodes = [
        {"module1", :module, %{name: "Module1", file: "module1.ex"}},
        {"function1", :function, %{name: "function1", module: "Module1"}}
      ]
      
      # Add these to both stores
      Enum.each(common_nodes, fn {id, type, attrs} ->
        Server.add_node(store1, id, type, attrs)
        Server.add_node(store2, id, type, attrs)
      end)
      
      # Add a common edge
      Server.add_edge(store1, "module1", "function1", :contains, %{})
      Server.add_edge(store2, "module1", "function1", :contains, %{})
      
      # Add store1-specific nodes and edges
      Server.add_node(store1, "store1_only", :module, %{name: "Store1Only"})
      Server.add_edge(store1, "store1_only", "function1", :calls, %{line: 10})
      
      # Add store2-specific nodes and edges
      Server.add_node(store2, "store2_only", :module, %{name: "Store2Only"})
      Server.add_edge(store2, "function1", "store2_only", :calls, %{line: 20})
      
      # Change an attribute in store2 for a common node
      Server.delete_node(store2, "module1")
      Server.add_node(store2, "module1", :module, %{name: "Module1", file: "module1_modified.ex"})
      
      {:ok, store1: store1, store2: store2}
    end
    
    test "finds differences between two stores", %{store1: store1, store2: store2} do
      {:ok, diff_result} = CrossQuery.diff(store1, store2)
      
      # Check node differences
      assert length(diff_result.nodes.added) == 1
      assert hd(diff_result.nodes.added).id == "store2_only"
      
      assert length(diff_result.nodes.removed) == 1
      assert hd(diff_result.nodes.removed).id == "store1_only"
      
      assert length(diff_result.nodes.modified) == 1
      modified_node = hd(diff_result.nodes.modified)
      assert modified_node.id == "module1"
      assert modified_node.store1.attributes.file == "module1.ex"
      assert modified_node.store2.attributes.file == "module1_modified.ex"
      
      # Check edge differences
      assert length(diff_result.edges.added) == 1
      assert hd(diff_result.edges.added).source_id == "function1"
      assert hd(diff_result.edges.added).target_id == "store2_only"
      
      assert length(diff_result.edges.removed) == 1
      assert hd(diff_result.edges.removed).source_id == "store1_only"
      assert hd(diff_result.edges.removed).target_id == "function1"
    end
    
    test "filters differences by node type", %{store1: store1, store2: store2} do
      {:ok, diff_result} = CrossQuery.diff(store1, store2, node_types: [:function])
      
      # Should not include module differences
      assert Enum.all?(diff_result.nodes.added, fn node -> node.type != :module end)
      assert Enum.all?(diff_result.nodes.removed, fn node -> node.type != :module end)
      assert Enum.all?(diff_result.nodes.modified, fn node -> node.store1.type != :module end)
    end
  end
  
  describe "cross-store queries" do
    setup %{test_id: test_id} do
      repo_path = "/tmp/test_repo_#{test_id}"
      
      # Create test stores that mimic branch stores
      {:ok, main_store} = create_and_register_branch_store(repo_path, "main", test_id)
      {:ok, dev_store} = create_and_register_branch_store(repo_path, "dev", test_id)
      {:ok, feature_store} = create_and_register_branch_store(repo_path, "feature", test_id)
      
      # Add common module to all branches
      common_module = {"common", :module, %{name: "Common", file: "common.ex"}}
      Enum.each([main_store, dev_store, feature_store], fn store ->
        Server.add_node(store, elem(common_module, 0), elem(common_module, 1), elem(common_module, 2))
      end)
      
      # Add branch-specific modules
      Server.add_node(main_store, "main_only", :module, %{name: "MainOnly"})
      Server.add_node(dev_store, "dev_only", :module, %{name: "DevOnly"})
      Server.add_node(feature_store, "feature_only", :module, %{name: "FeatureOnly"})
      
      # Return setup data
      {:ok, repo_path: repo_path, stores: %{
        "main" => main_store,
        "dev" => dev_store,
        "feature" => feature_store
      }}
    end
    
    test "queries across all branches", %{repo_path: repo_path} do
      # Execute query across all branches
      {:ok, results} = CrossQuery.query_across_branches(%{type: :module}, repo_path)
      
      # Should have results for all three branches
      assert map_size(results) == 3
      assert Map.has_key?(results, "main")
      assert Map.has_key?(results, "dev")
      assert Map.has_key?(results, "feature")
      
      # Each branch should have the common module plus its unique module
      Enum.each(results, fn {branch, branch_results} ->
        assert length(branch_results) == 2
        
        module_names = Enum.map(branch_results, fn node -> node.attributes.name end)
        assert "Common" in module_names
        
        branch_specific = case branch do
          "main" -> "MainOnly"
          "dev" -> "DevOnly"
          "feature" -> "FeatureOnly"
        end
        
        assert branch_specific in module_names
      end)
    end
    
    test "filters queries by branch", %{repo_path: repo_path} do
      # Execute query only on main and dev branches
      {:ok, results} = CrossQuery.query_across_branches(
        %{type: :module}, 
        repo_path, 
        branches: ["main", "dev"]
      )
      
      # Should only have results for two branches
      assert map_size(results) == 2
      assert Map.has_key?(results, "main")
      assert Map.has_key?(results, "dev")
      refute Map.has_key?(results, "feature")
    end
    
    test "merges results when requested", %{repo_path: repo_path} do
      # Execute query with merged results
      {:ok, results} = CrossQuery.query_across_branches(
        %{type: :module}, 
        repo_path, 
        merge_results: true
      )
      
      # Should have flattened results with branch information
      assert is_list(results)
      assert length(results) == 6  # 2 modules per branch * 3 branches
      
      # Each result should have a branch field
      Enum.each(results, fn result ->
        assert Map.has_key?(result, :branch)
        assert result.branch in ["main", "dev", "feature"]
      end)
      
      # Count results by branch
      results_by_branch = Enum.group_by(results, fn r -> r.branch end)
      assert map_size(results_by_branch) == 3
      assert length(results_by_branch["main"]) == 2
      assert length(results_by_branch["dev"]) == 2
      assert length(results_by_branch["feature"]) == 2
    end
  end
  
  describe "branch comparison" do
    setup %{test_id: test_id} do
      repo_path = "/tmp/test_repo_#{test_id}"
      
      # Create test stores for main and feature branches
      {:ok, main_store} = create_and_register_branch_store(repo_path, "main", test_id)
      {:ok, feature_store} = create_and_register_branch_store(repo_path, "feature", test_id)
      
      # Add common modules to both branches
      Server.add_node(main_store, "common", :module, %{name: "Common", file: "common.ex"})
      Server.add_node(feature_store, "common", :module, %{name: "Common", file: "common.ex"})
      
      # Add modified module (same ID, different attributes)
      Server.add_node(main_store, "modified", :module, %{name: "Modified", version: 1})
      Server.add_node(feature_store, "modified", :module, %{name: "Modified", version: 2})
      
      # Add branch-specific modules
      Server.add_node(main_store, "main_only", :module, %{name: "MainOnly"})
      Server.add_node(feature_store, "feature_only", :module, %{name: "FeatureOnly"})
      
      # Return setup data
      {:ok, repo_path: repo_path}
    end
    
    test "compares branches", %{repo_path: repo_path} do
      # Compare main with feature branch
      {:ok, diff_result} = CrossQuery.compare_branches(repo_path, "main", "feature")
      
      # Check node differences
      assert length(diff_result.nodes.added) == 1
      assert hd(diff_result.nodes.added).id == "feature_only"
      
      assert length(diff_result.nodes.removed) == 1
      assert hd(diff_result.nodes.removed).id == "main_only"
      
      assert length(diff_result.nodes.modified) == 1
      modified_node = hd(diff_result.nodes.modified)
      assert modified_node.id == "modified"
      assert modified_node.store1.attributes.version == 1
      assert modified_node.store2.attributes.version == 2
      
      # Common nodes should not be in the diff
      diff_node_ids = 
        diff_result.nodes.added 
        |> Enum.map(& &1.id) 
        |> Enum.concat(Enum.map(diff_result.nodes.removed, & &1.id)) 
        |> Enum.concat(Enum.map(diff_result.nodes.modified, & &1.id))
        
      refute "common" in diff_node_ids
    end
  end
  
  # Helper functions
  
  defp start_registry do
    # Start the registry if it doesn't exist
    case Registry.start_link(keys: :unique, name: GraphOS.Graph.StoreRegistry) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end
  
  defp create_test_store(name) do
    # Create a test store using the ETS adapter
    Server.start_link(
      name: String.to_atom(name),
      adapter: GraphOS.Graph.Store.ETS,
      adapter_opts: [name: name]
    )
  end
  
  defp create_and_register_branch_store(repo_path, branch, test_id) do
    # Create store with a name that mimics our branch naming convention
    store_name = "GraphOS.Core.CodeGraph.Store:#{repo_path}:#{branch}"
    
    # Start the store
    {:ok, pid} = Server.start_link(
      name: String.to_atom("#{store_name}_#{test_id}"),
      adapter: GraphOS.Graph.Store.ETS,
      adapter_opts: [name: "#{branch}_#{test_id}", repo_path: repo_path, branch: branch]
    )
    
    # Register it manually with the name matching our convention
    Registry.register(GraphOS.Graph.StoreRegistry, store_name, pid)
    
    {:ok, pid}
  end
end
