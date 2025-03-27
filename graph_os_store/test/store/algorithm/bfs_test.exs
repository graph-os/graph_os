defmodule GraphOS.Store.Algorithm.BFSTest do
  use ExUnit.Case, async: false

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Algorithm.BFS

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
    data = Map.get(attrs, :data, %{})

    # If type was provided, add it to the data map
    data = if type, do: Map.put(data, :type, type), else: data

    # Create a map instead of a struct
    %{
      id: id,
      source: source,
      target: target,
      data: data,
      # Include minimal metadata
      metadata: %{
        entity: :edge,
        module: Edge
      }
    }
  end

  setup do
    # Start with a clean slate for each test
    {:ok, _} = Store.init(name: :bfs_test)

    # Create a test graph of nodes to traverse
    # Node 1 connects to Node 2 and Node 4
    # Node 2 connects to Node 3 (which connects to Node 5)
    # Node 4 connects to Node 5 (which connects to Node 6)
    #
    # Diagram:
    #
    #    1
    #   / \
    #  2   4
    #  |   |
    #  3---5
    #      |
    #      6

    # Create test nodes
    node_1 = create_test_node(%{id: "node_1", data: %{name: "Node 1"}})
    node_2 = create_test_node(%{id: "node_2", data: %{name: "Node 2"}})
    node_3 = create_test_node(%{id: "node_3", data: %{name: "Node 3"}})
    node_4 = create_test_node(%{id: "node_4", data: %{name: "Node 4"}})
    node_5 = create_test_node(%{id: "node_5", data: %{name: "Node 5"}})
    node_6 = create_test_node(%{id: "node_6", data: %{name: "Node 6"}})

    # Insert nodes into the store
    {:ok, _} = Store.insert(Node, node_1)
    {:ok, _} = Store.insert(Node, node_2)
    {:ok, _} = Store.insert(Node, node_3)
    {:ok, _} = Store.insert(Node, node_4)
    {:ok, _} = Store.insert(Node, node_5)
    {:ok, _} = Store.insert(Node, node_6)

    # Create edges between nodes
    edge_1_2 = create_test_edge(%{source: "node_1", target: "node_2"})
    edge_1_4 = create_test_edge(%{source: "node_1", target: "node_4"})
    edge_2_3 = create_test_edge(%{source: "node_2", target: "node_3"})
    edge_3_5 = create_test_edge(%{source: "node_3", target: "node_5"})
    edge_4_5 = create_test_edge(%{source: "node_4", target: "node_5"})
    edge_5_6 = create_test_edge(%{source: "node_5", target: "node_6"})

    # Insert edges into the store
    {:ok, _} = Store.insert(Edge, edge_1_2)
    {:ok, _} = Store.insert(Edge, edge_1_4)
    {:ok, _} = Store.insert(Edge, edge_2_3)
    {:ok, _} = Store.insert(Edge, edge_3_5)
    {:ok, _} = Store.insert(Edge, edge_4_5)
    {:ok, _} = Store.insert(Edge, edge_5_6)

    :ok
  end

  describe "BFS.execute/2" do
    test "traverses graph in breadth-first order" do
      # Starting from node_1
      {:ok, result} = BFS.execute("node_1", [])

      # Extract node IDs for easier assertions
      node_ids = Enum.map(result, fn node -> node.id end)

      # First node should be the starting node
      assert List.first(node_ids) == "node_1"

      # Direct neighbors should come before indirect neighbors
      # Direct neighbors of node_1 are node_2 and node_4
      direct_neighbors = Enum.slice(node_ids, 1, 2)
      assert Enum.sort(direct_neighbors) == ["node_2", "node_4"]

      # We should eventually visit all reachable nodes
      assert length(node_ids) == 6
      assert Enum.sort(node_ids) == ["node_1", "node_2", "node_3", "node_4", "node_5", "node_6"]
    end

    test "respects max_depth option" do
      # BFS with depth limit of 1 (only direct neighbors)
      {:ok, result} = BFS.execute("node_1", [max_depth: 1])

      node_ids = Enum.map(result, fn node -> node.id end)

      # Should only include node_1 and its direct neighbors
      assert length(node_ids) == 3
      assert Enum.sort(node_ids) == ["node_1", "node_2", "node_4"]
    end

    test "handles direction option" do
      # Incoming direction (nodes that point to node_5)
      {:ok, result} = BFS.execute("node_5", [direction: :incoming])

      node_ids = Enum.map(result, fn node -> node.id end)

      # Should include node_5 and the nodes that have edges pointing to it
      assert Enum.member?(node_ids, "node_3")
      assert Enum.member?(node_ids, "node_4")
    end

    test "handles both direction option" do
      # Both directions from node_3
      {:ok, result} = BFS.execute("node_3", [direction: :both])

      node_ids = Enum.map(result, fn node -> node.id end)

      # Should follow all connected edges regardless of direction
      assert Enum.member?(node_ids, "node_2") # Incoming
      assert Enum.member?(node_ids, "node_5") # Outgoing
    end

    test "handles edge_type option" do
      # Create edges with specific types
      typed_edge_1 = create_test_edge(%{
        id: "edge_special_1",
        source: "node_4",
        target: "node_3",
        type: "special"
      })
      typed_edge_2 = create_test_edge(%{
        id: "edge_special_2",
        source: "node_5",
        target: "node_1",
        type: "special"
      })

      {:ok, _} = Store.insert(Edge, typed_edge_1)
      {:ok, _} = Store.insert(Edge, typed_edge_2)

      # BFS with specific edge type
      {:ok, result} = BFS.execute("node_4", [edge_type: "special"])

      node_ids = Enum.map(result, fn node -> node.id end)

      # Should only follow edges of type "special"
      assert Enum.member?(node_ids, "node_3")

      # Should not include nodes reached by regular edges
      refute Enum.member?(node_ids, "node_5")
    end

    test "handles cycles in the graph" do
      # Create a cycle by adding an edge from node_6 back to node_1
      cycle_edge = create_test_edge(%{
        id: "edge_cycle",
        source: "node_6",
        target: "node_1"
      })
      {:ok, _} = Store.insert(Edge, cycle_edge)

      # BFS should still work without infinite loops
      {:ok, result} = BFS.execute("node_1", [])

      # Should visit all nodes exactly once
      node_ids = Enum.map(result, fn node -> node.id end)
      unique_ids = Enum.uniq(node_ids)

      assert length(node_ids) == length(unique_ids)
      assert length(node_ids) == 6
    end
  end
end
