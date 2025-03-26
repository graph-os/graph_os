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
    {:ok, _} = Store.init(name: :bfs_test)

    # Create a test graph
    # (1) -> (2) -> (3)
    #  |      |      |
    #  v      v      v
    # (4) -> (5) -> (6)

    # Create nodes
    nodes = for i <- 1..6 do
      node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
      {:ok, _} = Store.insert(Node, node)
      node
    end

    # Create edges in a grid pattern
    edges = [
      {"node_1", "node_2"}, # horizontal edges
      {"node_2", "node_3"},
      {"node_4", "node_5"},
      {"node_5", "node_6"},
      {"node_1", "node_4"}, # vertical edges
      {"node_2", "node_5"},
      {"node_3", "node_6"}
    ]

    for {source, target} <- edges do
      edge = create_test_edge(%{id: "edge_#{source}_#{target}", source: source, target: target})
      {:ok, _} = Store.insert(Edge, edge)
    end

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
      # Create bidirectional edge for testing
      bidirectional_edge = create_test_edge(%{
        id: "edge_node_5_node_2",
        source: "node_5",
        target: "node_2"
      })
      {:ok, _} = Store.insert(Edge, bidirectional_edge)

      # Test with outgoing edges (default)
      {:ok, outgoing_result} = BFS.execute("node_2", [])
      outgoing_ids = MapSet.new(Enum.map(outgoing_result, fn node -> node.id end))

      # Test with incoming edges
      {:ok, incoming_result} = BFS.execute("node_2", [direction: :incoming])
      incoming_ids = MapSet.new(Enum.map(incoming_result, fn node -> node.id end))

      # Test with both directions
      {:ok, both_result} = BFS.execute("node_2", [direction: :both])
      both_ids = MapSet.new(Enum.map(both_result, fn node -> node.id end))

      # Outgoing from node_2 should include node_3, node_5 and their descendants
      assert MapSet.member?(outgoing_ids, "node_3")
      assert MapSet.member?(outgoing_ids, "node_5")

      # Incoming to node_2 should include node_1
      assert MapSet.member?(incoming_ids, "node_1")

      # Both directions should include all connected nodes
      assert MapSet.size(both_ids) >= MapSet.size(outgoing_ids)
      assert MapSet.size(both_ids) >= MapSet.size(incoming_ids)
    end

    test "returns error for non-existent start node" do
      {:error, :node_not_found} = BFS.execute("nonexistent_node", [])
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
