defmodule GraphOS.StoreTest do
  use ExUnit.Case, async: true

  alias GraphOS.Store
  alias GraphOS.Entity.{Node, Edge}

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
    type = Map.get(attrs, :type)

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

  setup do
    # Initialize a fresh store for each test
    {:ok, _} = Store.init(name: :test_store)
    :ok
  end

  describe "Store.init/1" do
    test "initializes with default values" do
      {:ok, store_name} = Store.init()
      assert store_name == :default
    end

    test "initializes with custom name" do
      {:ok, store_name} = Store.init(name: :custom_store)
      assert store_name == :custom_store
    end
  end

  describe "Store CRUD operations" do
    test "insert/2 creates an entity" do
      node = create_test_node(%{id: "test_node", data: %{name: "Test Node"}})

      {:ok, stored_node} = Store.insert(Node, node)

      assert stored_node.id == "test_node"
      assert stored_node.data.name == "Test Node"
    end

    test "get/2 retrieves an entity" do
      node = create_test_node(%{id: "get_node", data: %{name: "Get Node"}})
      {:ok, _} = Store.insert(Node, node)

      {:ok, retrieved_node} = Store.get(Node, "get_node")

      assert retrieved_node.id == "get_node"
      assert retrieved_node.data.name == "Get Node"
    end

    test "update/2 updates an entity" do
      # Create initial node
      node = create_test_node(%{id: "update_node", data: %{name: "Original Name"}})
      {:ok, stored_node} = Store.insert(Node, node)

      # Update node
      updated_node = %{stored_node | data: %{name: "Updated Name"}}
      {:ok, result} = Store.update(Node, updated_node)

      assert result.data.name == "Updated Name"

      # Verify it was updated in the store
      {:ok, retrieved} = Store.get(Node, "update_node")
      assert retrieved.data.name == "Updated Name"
    end

    test "delete/2 removes an entity" do
      # Create a node to delete
      node = create_test_node(%{id: "delete_node", data: %{name: "Delete Me"}})
      {:ok, _} = Store.insert(Node, node)

      # Verify it exists
      {:ok, _} = Store.get(Node, "delete_node")

      # Delete it
      :ok = Store.delete(Node, "delete_node")

      # Verify it's gone
      {:error, :not_found} = Store.get(Node, "delete_node")
    end

    test "all/2 returns all entities of a type" do
      # Create several nodes
      Enum.each(1..3, fn i ->
        node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
        {:ok, _} = Store.insert(Node, node)
      end)

      {:ok, nodes} = Store.all(Node)

      assert length(nodes) == 3
      assert Enum.any?(nodes, fn node -> node.id == "node_1" end)
      assert Enum.any?(nodes, fn node -> node.id == "node_2" end)
      assert Enum.any?(nodes, fn node -> node.id == "node_3" end)
    end

    test "all/3 with filter returns filtered entities" do
      # Create nodes with different attributes
      node1 = create_test_node(%{id: "filtered_1", data: %{category: "A", value: 10}})
      node2 = create_test_node(%{id: "filtered_2", data: %{category: "A", value: 20}})
      node3 = create_test_node(%{id: "filtered_3", data: %{category: "B", value: 30}})

      {:ok, _} = Store.insert(Node, node1)
      {:ok, _} = Store.insert(Node, node2)
      {:ok, _} = Store.insert(Node, node3)

      # Filter by category A
      {:ok, category_a_nodes} = Store.all(Node, %{data: %{category: "A"}})

      assert length(category_a_nodes) == 2
      assert Enum.all?(category_a_nodes, fn node -> node.data.category == "A" end)
    end
  end

  describe "Store graph operations" do
    setup do
      # Create a small graph with nodes and edges
      nodes = for i <- 1..5 do
        node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
        {:ok, _} = Store.insert(Node, node)
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
        {:ok, _} = Store.insert(Edge, edge)
      end

      :ok
    end

    test "traverse/2 with BFS algorithm" do
      {:ok, result} = Store.traverse(:bfs, {"node_1", []})

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

    test "traverse/2 with shortest_path algorithm" do
      {:ok, path, _distance} = Store.traverse(:shortest_path, {"node_1", "node_5", []})

      # Extract path node IDs
      path_ids = Enum.map(path, fn node -> node.id end)

      # Path should start with node_1 and end with node_5
      assert List.first(path_ids) == "node_1"
      assert List.last(path_ids) == "node_5"

      # There are multiple possible shortest paths
      # One possible path is 1->3->4->5
      assert length(path) <= 4, "Path should be no more than 4 nodes long"
    end

    test "traverse/2 with unsupported algorithm" do
      {:error, {:unsupported_algorithm, :invalid_algorithm}} =
        Store.traverse(:invalid_algorithm, {})
    end
  end
end
