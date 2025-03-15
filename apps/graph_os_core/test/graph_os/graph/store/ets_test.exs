defmodule GraphOS.Graph.Store.ETSTest do
  use ExUnit.Case, async: true
  
  alias GraphOS.Graph.Store.ETS
  
  describe "initialization" do
    test "initializes ETS store with proper configuration" do
      {:ok, state} = ETS.init(name: "test_store", repo_path: "/tmp/repo", branch: "main")
      
      assert state.name == "test_store"
      assert state.repo_path == "/tmp/repo"
      assert state.branch == "main"
      assert is_atom(state.nodes_table)
      assert is_atom(state.edges_table)
      assert is_atom(state.metadata_table)
    end
  end
  
  describe "node operations" do
    setup do
      {:ok, state} = ETS.init(name: "node_test_#{System.unique_integer([:positive])}")
      {:ok, state: state}
    end
    
    test "adds and retrieves a node", %{state: state} do
      node_id = "test_node_1"
      node_type = :module
      attributes = %{name: "TestModule", file: "test.ex"}
      
      {:ok, ^node_id} = ETS.add_node(state, node_id, node_type, attributes)
      {:ok, node} = ETS.get_node(state, node_id)
      
      assert node.id == node_id
      assert node.type == node_type
      assert node.attributes == attributes
    end
    
    test "retrieves nodes by filter", %{state: state} do
      # Add several nodes
      ETS.add_node(state, "mod1", :module, %{name: "Mod1", file: "mod1.ex"})
      ETS.add_node(state, "mod2", :module, %{name: "Mod2", file: "mod2.ex"})
      ETS.add_node(state, "fun1", :function, %{name: "fun1", module: "Mod1"})
      
      # Filter by type
      {:ok, modules} = ETS.get_nodes(state, %{type: :module})
      assert length(modules) == 2
      
      # Filter by attributes
      {:ok, mod1} = ETS.get_nodes(state, %{attributes: %{name: "Mod1"}})
      assert length(mod1) == 1
      assert hd(mod1).id == "mod1"
    end
    
    test "deletes a node", %{state: state} do
      node_id = "to_delete"
      ETS.add_node(state, node_id, :module, %{name: "ToDelete"})
      
      :ok = ETS.delete_node(state, node_id)
      assert {:error, :not_found} = ETS.get_node(state, node_id)
    end
  end
  
  describe "edge operations" do
    setup do
      {:ok, state} = ETS.init(name: "edge_test_#{System.unique_integer([:positive])}")
      
      # Add some nodes for edges
      ETS.add_node(state, "mod1", :module, %{name: "Mod1"})
      ETS.add_node(state, "fun1", :function, %{name: "fun1"})
      ETS.add_node(state, "fun2", :function, %{name: "fun2"})
      
      {:ok, state: state}
    end
    
    test "adds and retrieves an edge", %{state: state} do
      source_id = "mod1"
      target_id = "fun1"
      edge_type = :contains
      attributes = %{}
      
      {:ok, edge_id} = ETS.add_edge(state, source_id, target_id, edge_type, attributes)
      {:ok, edge} = ETS.get_edge(state, source_id, target_id, edge_type)
      
      assert edge.id == edge_id
      assert edge.source_id == source_id
      assert edge.target_id == target_id
      assert edge.type == edge_type
    end
    
    test "retrieves edges by filter", %{state: state} do
      # Add several edges
      ETS.add_edge(state, "mod1", "fun1", :contains, %{})
      ETS.add_edge(state, "mod1", "fun2", :contains, %{})
      ETS.add_edge(state, "fun1", "fun2", :calls, %{line: 10})
      
      # Filter by source
      {:ok, mod1_edges} = ETS.get_edges(state, %{source_id: "mod1"})
      assert length(mod1_edges) == 2
      
      # Filter by type
      {:ok, calls_edges} = ETS.get_edges(state, %{type: :calls})
      assert length(calls_edges) == 1
      assert hd(calls_edges).source_id == "fun1"
    end
    
    test "deletes an edge", %{state: state} do
      source_id = "mod1"
      target_id = "fun1"
      edge_type = :contains
      
      ETS.add_edge(state, source_id, target_id, edge_type, %{})
      :ok = ETS.delete_edge(state, source_id, target_id, edge_type)
      
      assert {:error, :not_found} = ETS.get_edge(state, source_id, target_id, edge_type)
    end
  end
  
  describe "query operations" do
    setup do
      {:ok, state} = ETS.init(name: "query_test_#{System.unique_integer([:positive])}")
      
      # Set up a small graph
      ETS.add_node(state, "mod1", :module, %{name: "Mod1"})
      ETS.add_node(state, "fun1", :function, %{name: "fun1", module: "Mod1"})
      ETS.add_node(state, "fun2", :function, %{name: "fun2", module: "Mod1"})
      ETS.add_node(state, "mod2", :module, %{name: "Mod2"})
      ETS.add_node(state, "fun3", :function, %{name: "fun3", module: "Mod2"})
      
      ETS.add_edge(state, "mod1", "fun1", :contains, %{})
      ETS.add_edge(state, "mod1", "fun2", :contains, %{})
      ETS.add_edge(state, "mod2", "fun3", :contains, %{})
      ETS.add_edge(state, "fun1", "fun3", :calls, %{line: 15})
      
      {:ok, state: state}
    end
    
    test "executes a simple query", %{state: state} do
      {:ok, results} = ETS.query(state, %{type: :module, attributes: %{name: "Mod1"}})
      
      assert length(results) == 1
      module = hd(results)
      assert module.id == "mod1"
      assert length(module.outgoing_edges) == 2
      assert length(module.incoming_edges) == 0
    end
    
    test "retrieves connected nodes", %{state: state} do
      {:ok, results} = ETS.query(state, %{type: :function, attributes: %{name: "fun1"}})
      
      assert length(results) == 1
      function = hd(results)
      assert function.id == "fun1"
      
      # fun1 has one outgoing edge (calls) and one incoming edge (contains)
      assert length(function.outgoing_edges) == 1
      assert length(function.incoming_edges) == 1
      
      outgoing = hd(function.outgoing_edges)
      assert outgoing.target_id == "fun3"
      assert outgoing.type == :calls
    end
  end
  
  describe "metadata operations" do
    test "stores and retrieves metadata" do
      {:ok, state} = ETS.init(name: "metadata_test", repo_path: "/test/repo", branch: "develop")
      
      {:ok, metadata} = ETS.get_metadata(state)
      
      assert metadata.repo_path == "/test/repo"
      assert metadata.branch == "develop"
      assert %DateTime{} = metadata.initialized_at
    end
  end
  
  describe "clearing data" do
    test "clears all data from tables" do
      {:ok, state} = ETS.init(name: "clear_test")
      
      # Add some data
      ETS.add_node(state, "node1", :module, %{})
      ETS.add_node(state, "node2", :function, %{})
      ETS.add_edge(state, "node1", "node2", :contains, %{})
      
      # Verify data exists
      {:ok, nodes} = ETS.get_all_nodes(state)
      assert length(nodes) == 2
      
      # Clear data
      :ok = ETS.clear(state)
      
      # Verify data is gone
      {:ok, nodes_after} = ETS.get_all_nodes(state)
      assert nodes_after == []
      
      {:ok, edges_after} = ETS.get_all_edges(state)
      assert edges_after == []
    end
  end
end
