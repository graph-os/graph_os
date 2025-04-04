defmodule GraphOS.StoreTest do
  use ExUnit.Case, async: false

  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS # Add alias for ETS adapter
  alias GraphOS.Entity.{Node, Edge}

  defmodule CustomNode do
    use GraphOS.Entity.Node

    # Should only validate the node.data object
    def data_schema do
      GraphOS.Entity.Schema.define(:data, [])
    end
  end

  # Create a simple test metadata map for our tests
  def test_metadata(module) do
    entity_type = case module do
      Node -> :node
      Edge -> :edge
      _ -> :metadata
    end

    # Create metadata without calling GraphOS.Entity.Metadata.new/1
    %{
      entity: entity_type,
      module: module,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      version: 1,
      deleted: false
    }
  end

  # Helper to create a test Node as a map
  def create_test_node(attrs) do
    id = Map.get(attrs, :id, GraphOS.Entity.generate_id())
    data = Map.get(attrs, :data, %{})

    # Create a map instead of a struct
    %{
      id: id,
      data: data,
      # Include minimal metadata
      metadata: %{
        entity: :node,
        module: Node
      }
    }
  end

  # Helper to create a test Edge as a map
  def create_test_edge(attrs) do
    id = Map.get(attrs, :id, GraphOS.Entity.generate_id())
    source = Map.get(attrs, :source)
    target = Map.get(attrs, :target)
    type = Map.get(attrs, :type, :default) # Always provide a default type

    # Create a map instead of a struct
    %{
      id: id,
      source: source,
      target: target,
      type: type,
      # Include minimal metadata
      metadata: %{
        entity: :edge,
        module: Edge
      }
    }
  end

  # Updated setup to use start_link and add on_exit
  setup do
    store_name = :test_store
    # Start the store process
    {:ok, _pid} = GraphOS.Store.start_link(name: store_name, adapter: ETS)
    # Ensure the store is stopped when the test exits with better error handling
    on_exit(fn -> 
      try do
        GraphOS.Store.stop(store_name)
      catch
        :exit, _ -> :ok
      end
    end)
    # Return the store name in the context
    {:ok, %{store_name: store_name}}
  end

  describe "Store CRUD operations" do
    # Pass context (including store_name) to tests
    test "insert/3 creates an entity", %{store_name: store_name} do
      node = create_test_node(%{id: "test_node", data: %{name: "Test Node"}})

      # Use the 3-arity version with store_name
      {:ok, stored_node} = Store.insert(store_name, Node, node)

      assert stored_node.id == "test_node"
      assert stored_node.data.name == "Test Node"
    end

    test "get/3 retrieves an entity", %{store_name: store_name} do
      node = create_test_node(%{id: "get_node", data: %{name: "Get Node"}})
      {:ok, _} = Store.insert(store_name, Node, node)

      {:ok, retrieved_node} = Store.get(store_name, Node, "get_node")

      assert retrieved_node.id == "get_node"
      assert retrieved_node.data.name == "Get Node"
    end

    test "update/3 updates an entity", %{store_name: store_name} do
      # Create initial node
      node = create_test_node(%{id: "update_node", data: %{name: "Original Name"}})
      {:ok, stored_node} = Store.insert(store_name, Node, node)

      # Update node
      updated_node = %{stored_node | data: %{name: "Updated Name"}}
      {:ok, result} = Store.update(store_name, Node, updated_node)

      assert result.data.name == "Updated Name"

      # Verify it was updated in the store
      {:ok, retrieved} = Store.get(store_name, Node, "update_node")
      assert retrieved.data.name == "Updated Name"
    end

    test "delete/3 removes an entity", %{store_name: store_name} do
      # Create a node to delete
      node = create_test_node(%{id: "delete_node", data: %{name: "Delete Me"}})
      {:ok, _} = Store.insert(store_name, Node, node)

      # Verify it exists
      {:ok, _} = Store.get(store_name, Node, "delete_node")

      # Delete it
      :ok = Store.delete(store_name, Node, "delete_node")

      # Verify it's gone (should return deleted error or not_found based on implementation)
      # Adapter returns :ok for successful delete, get returns :error, :deleted or :not_found
      assert {:error, _reason} = Store.get(store_name, Node, "delete_node")
    end

    # Test all/4 explicitly
    test "all/4 returns all entities of a type", %{store_name: store_name} do
      # Create several nodes
      Enum.each(1..3, fn i ->
        node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
        {:ok, _} = Store.insert(store_name, Node, node)
      end)

      {:ok, nodes} = Store.all(store_name, Node, %{}, []) # Use 4-arity version

      assert length(nodes) == 3
      assert Enum.any?(nodes, fn node -> node.id == "node_1" end)
      assert Enum.any?(nodes, fn node -> node.id == "node_2" end)
      assert Enum.any?(nodes, fn node -> node.id == "node_3" end)
    end

    test "all/4 with filter returns filtered entities", %{store_name: store_name} do
      # Create nodes with different attributes
      node1 = create_test_node(%{id: "filtered_1", data: %{category: "A", value: 10}})
      node2 = create_test_node(%{id: "filtered_2", data: %{category: "A", value: 20}})
      node3 = create_test_node(%{id: "filtered_3", data: %{category: "B", value: 30}})

      {:ok, _} = Store.insert(store_name, Node, node1)
      {:ok, _} = Store.insert(store_name, Node, node2)
      {:ok, _} = Store.insert(store_name, Node, node3)

      # Filter by category A
      {:ok, category_a_nodes} = Store.all(store_name, Node, %{data: %{category: "A"}}, [])

      assert length(category_a_nodes) == 2
      assert Enum.all?(category_a_nodes, fn node -> node.data.category == "A" end)
    end
  end

  describe "Store graph operations" do
    # Also needs the context for store_name
    setup %{store_name: store_name} do
      # Create a small graph with nodes and edges
      _nodes = for i <- 1..5 do
        node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
        {:ok, _} = Store.insert(store_name, Node, node) # Use store_name
        node
      end

      # Create edges: 1->2->3->4->5, and 1->3, 2->4
      edges = [
        {"node_1", "node_2"},
        {"node_2", "node_3"},
        {"node_3", "node_4"},
        {"node_4", "node_5"},
        {"node_1", "node_3"},
        {"node_2", "node_4"}
      ]

      for {source, target} <- edges do
        edge = create_test_edge(%{id: "edge_#{source}_#{target}", source: source, target: target})
        {:ok, _} = Store.insert(store_name, Edge, edge) # Use store_name
      end

      :ok
    end

    test "traverse/3 with BFS algorithm", %{store_name: store_name} do
      {:ok, result} = Store.traverse(store_name, :bfs, {"node_1", []})

      # We should get nodes in BFS order
      node_ids = Enum.map(result, fn node -> node.id end)

      # First node should be the start node
      assert List.first(node_ids) == "node_1"

      # BFS should visit node_2 and node_3 before node_4
      # since they're direct neighbors of node_1 and node_2
      assert Enum.member?(node_ids, "node_2")
      assert Enum.member?(node_ids, "node_3")
      assert Enum.member?(node_ids, "node_4")
      assert Enum.member?(node_ids, "node_5")
    end

    test "traverse/3 with shortest_path algorithm", %{store_name: store_name} do
      {:ok, path, _distance} = Store.traverse(store_name, :shortest_path, {"node_1", "node_5", []})

      # Extract path node IDs
      path_ids = Enum.map(path, fn node -> node.id end)

      # Path should start with node_1 and end with node_5
      assert List.first(path_ids) == "node_1"
      assert List.last(path_ids) == "node_5"

      # There are multiple possible shortest paths
      # One possible path is 1->3->4->5
      assert length(path) <= 4, "Path should be no more than 4 nodes long"
    end

    test "traverse/3 with unsupported algorithm", %{store_name: store_name} do
      {:error, {:unsupported_algorithm, :invalid_algorithm}} =
        Store.traverse(store_name, :invalid_algorithm, {})
    end
  end
end
