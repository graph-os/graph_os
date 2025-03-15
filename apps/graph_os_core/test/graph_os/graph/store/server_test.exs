defmodule GraphOS.Graph.Store.ServerTest do
  use ExUnit.Case, async: true
  @moduletag :code_graph
  
  alias GraphOS.Graph.Store.Server
  
  # Create a mock store implementation for testing
  defmodule MockStore do
    @behaviour GraphOS.Graph.Store
    
    def init(opts) do
      {:ok, %{name: Keyword.get(opts, :name, "mock")}}
    end
    
    def add_node(_state, node_id, type, attributes) do
      send(self(), {:add_node, node_id, type, attributes})
      {:ok, node_id}
    end
    
    def add_edge(_state, source_id, target_id, type, attributes) do
      edge_id = "#{source_id}->#{target_id}:#{type}"
      send(self(), {:add_edge, source_id, target_id, type, attributes})
      {:ok, edge_id}
    end
    
    def get_node(_state, node_id) do
      send(self(), {:get_node, node_id})
      {:ok, %{id: node_id, type: :mock, attributes: %{}}}
    end
    
    def get_nodes(_state, filter) do
      send(self(), {:get_nodes, filter})
      {:ok, [%{id: "mock_node", type: :mock, attributes: %{}}]}
    end
    
    def get_edge(_state, source_id, target_id, type) do
      send(self(), {:get_edge, source_id, target_id, type})
      edge_id = "#{source_id}->#{target_id}:#{type}"
      {:ok, %{id: edge_id, source_id: source_id, target_id: target_id, type: type, attributes: %{}}}
    end
    
    def get_edges(_state, filter) do
      send(self(), {:get_edges, filter})
      {:ok, [%{id: "mock_edge", source_id: "source", target_id: "target", type: :mock, attributes: %{}}]}
    end
    
    def query(_state, query_map, _opts) do
      send(self(), {:query, query_map})
      {:ok, [%{id: "query_result", type: :mock, attributes: %{}, outgoing_edges: [], incoming_edges: []}]}
    end
    
    def delete_node(_state, node_id) do
      send(self(), {:delete_node, node_id})
      :ok
    end
    
    def delete_edge(_state, source_id, target_id, type) do
      send(self(), {:delete_edge, source_id, target_id, type})
      :ok
    end
    
    def clear(_state) do
      send(self(), :clear)
      :ok
    end
    
    def get_all_nodes(_state) do
      send(self(), :get_all_nodes)
      {:ok, [%{id: "all_node", type: :mock, attributes: %{}}]}
    end
    
    def get_all_edges(_state) do
      send(self(), :get_all_edges)
      {:ok, [%{id: "all_edge", source_id: "source", target_id: "target", type: :mock, attributes: %{}}]}
    end
    
    def get_metadata(_state) do
      send(self(), :get_metadata)
      {:ok, %{name: "mock"}}
    end
  end
  
  describe "server lifecycle" do
    test "starts and initializes the server" do
      {:ok, pid} = Server.start_link(name: "test_server", adapter: MockStore, adapter_opts: [])
      assert Process.alive?(pid)
    end
    
    test "server can be registered with a name" do
      name = :'GraphOS.Graph.Store.Server.test_#{System.unique_integer([:positive])}'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      
      # Should be able to call the server by name
      assert is_pid(Process.whereis(name))
    end
  end
  
  describe "node operations" do
    setup do
      name = :'GraphOS.Graph.Store.Server.node_test'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      {:ok, server: name}
    end
    
    test "adds a node", %{server: server} do
      result = Server.add_node(server, "test_node", :module, %{name: "TestModule"})
      assert {:ok, "test_node"} = result
      assert_received {:add_node, "test_node", :module, %{name: "TestModule"}}
    end
    
    test "gets a node", %{server: server} do
      result = Server.get_node(server, "test_node")
      assert {:ok, %{id: "test_node"}} = result
      assert_received {:get_node, "test_node"}
    end
    
    test "gets nodes by filter", %{server: server} do
      filter = %{type: :module}
      result = Server.get_nodes(server, filter)
      assert {:ok, [%{id: "mock_node"}]} = result
      assert_received {:get_nodes, ^filter}
    end
    
    test "deletes a node", %{server: server} do
      result = Server.delete_node(server, "test_node")
      assert :ok = result
      assert_received {:delete_node, "test_node"}
    end
  end
  
  describe "edge operations" do
    setup do
      name = :'GraphOS.Graph.Store.Server.edge_test'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      {:ok, server: name}
    end
    
    test "adds an edge", %{server: server} do
      result = Server.add_edge(server, "source", "target", :depends_on, %{weight: 1})
      assert {:ok, "source->target:depends_on"} = result
      assert_received {:add_edge, "source", "target", :depends_on, %{weight: 1}}
    end
    
    test "gets an edge", %{server: server} do
      result = Server.get_edge(server, "source", "target", :depends_on)
      assert {:ok, %{source_id: "source", target_id: "target", type: :depends_on}} = result
      assert_received {:get_edge, "source", "target", :depends_on}
    end
    
    test "gets edges by filter", %{server: server} do
      filter = %{type: :depends_on}
      result = Server.get_edges(server, filter)
      assert {:ok, [%{id: "mock_edge"}]} = result
      assert_received {:get_edges, ^filter}
    end
    
    test "deletes an edge", %{server: server} do
      result = Server.delete_edge(server, "source", "target", :depends_on)
      assert :ok = result
      assert_received {:delete_edge, "source", "target", :depends_on}
    end
  end
  
  describe "query operations" do
    setup do
      name = :'GraphOS.Graph.Store.Server.query_test'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      {:ok, server: name}
    end
    
    test "executes a query", %{server: server} do
      query = %{type: :module, attributes: %{name: "TestModule"}}
      result = Server.query(server, query)
      assert {:ok, [%{id: "query_result"}]} = result
      assert_received {:query, ^query}
    end
  end
  
  describe "metadata operations" do
    setup do
      name = :'GraphOS.Graph.Store.Server.metadata_test'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      {:ok, server: name}
    end
    
    test "retrieves metadata", %{server: server} do
      result = Server.get_metadata(server)
      assert {:ok, %{name: "mock"}} = result
      assert_received :get_metadata
    end
  end
  
  describe "bulk operations" do
    setup do
      name = :'GraphOS.Graph.Store.Server.bulk_test'
      {:ok, _pid} = Server.start_link(name: name, adapter: MockStore, adapter_opts: [])
      {:ok, server: name}
    end
    
    test "clears all data", %{server: server} do
      result = Server.clear(server)
      assert :ok = result
      assert_received :clear
    end
    
    test "retrieves all nodes", %{server: server} do
      result = Server.get_all_nodes(server)
      assert {:ok, [%{id: "all_node"}]} = result
      assert_received :get_all_nodes
    end
    
    test "retrieves all edges", %{server: server} do
      result = Server.get_all_edges(server)
      assert {:ok, [%{id: "all_edge"}]} = result
      assert_received :get_all_edges
    end
  end
end
