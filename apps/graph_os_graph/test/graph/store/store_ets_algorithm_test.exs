defmodule GraphOS.Store.Algorithm.ETSTest do
  @moduledoc """
  Tests for the GraphOS.Store.Algorithm module with the ETS adapter.
  """
  use ExUnit.Case

  alias GraphOS.Store
  alias GraphOS.Store.{Node, Edge, Query, Operation}

  setup do
    # Initialize the store before each test
    {:ok, store_name} = Store.start()

    # Create test graph nodes
    nodes = [
      %{id: "1", data: %{name: "Node 1"}},
      %{id: "2", data: %{name: "Node 2"}},
      %{id: "3", data: %{name: "Node 3"}},
      %{id: "4", data: %{name: "Node 4"}},
      %{id: "5", data: %{name: "Node 5"}}
    ]

    Enum.each(nodes, fn node ->
      Store.execute(Operation.new(:insert, :node, node.data, id: node.id))
    end)

    # Create test graph edges with weights
    edges = [
      %{id: "e1", source: "1", target: "2", data: %{weight: 5.0}},
      %{id: "e2", source: "1", target: "3", data: %{weight: 2.0}},
      %{id: "e3", source: "2", target: "3", data: %{weight: 1.0}},
      %{id: "e4", source: "2", target: "4", data: %{weight: 3.0}},
      %{id: "e5", source: "3", target: "4", data: %{weight: 7.0}},
      %{id: "e6", source: "3", target: "5", data: %{weight: 4.0}},
      %{id: "e7", source: "4", target: "5", data: %{weight: 6.0}}
    ]

    Enum.each(edges, fn edge ->
      Store.execute(
        Operation.new(:insert, :edge, edge.data,
          id: edge.id,
          source: edge.source,
          target: edge.target
        )
      )
    end)

    # Clean up after each test
    on_exit(fn -> Store.stop() end)

    # Return test data
    %{nodes: nodes, edges: edges, store: store_name}
  end

  describe "traversal algorithms" do
    test "can perform BFS traversal", %{store: store} do
      # Test the BFS traversal through the updated Algorithm module
      {:ok, result} = Store.Algorithm.bfs("1", max_depth: 2)

      # Test that we can reach nodes within 2 hops
      node_ids = Enum.map(result, fn node -> node.id end)
      assert "1" in node_ids
      assert "2" in node_ids
      assert "3" in node_ids
      # Node 4 is actually reachable within 2 hops
      assert "4" in node_ids

      # Node 5 is actually 2 hops away from node 1 in our test graph (1 -> 3 -> 5)
      # So it should be included when max_depth is 2
      assert "5" in node_ids
    end

    @tag :skip
    test "can find shortest path", %{nodes: _nodes, edges: _edges} do
      # Use the algorithm module to find the shortest path
      {:ok, path, distance} = Store.Algorithm.shortest_path("1", "5")

      # The shortest path should be 1 -> 3 -> 5 with total weight 6.0
      path_ids = Enum.map(path, fn node -> node.id end)

      assert path_ids == ["1", "3", "5"]
      assert distance == 6.0
    end

    @tag :skip
    test "can find connected components", %{nodes: _nodes, edges: _edges} do
      # Add an isolated node to create a second component
      Store.execute(Operation.new(:insert, :node, %{name: "Isolated Node"}, id: "6"))

      # Find connected components
      {:ok, components} = Store.Algorithm.connected_components()

      # We should have 2 components: one with nodes 1-5 and one with just node 6
      assert length(components) == 2

      # Find the bigger component
      main_component =
        Enum.find(components, fn component -> length(component) > 1 end)

      # Check that main component has all connected nodes
      main_component_ids = Enum.map(main_component, fn node -> node.id end)

      assert "1" in main_component_ids
      assert "2" in main_component_ids
      assert "3" in main_component_ids
      assert "4" in main_component_ids
      assert "5" in main_component_ids
      refute "6" in main_component_ids

      # Find the isolated component
      isolated_component =
        Enum.find(components, fn component -> length(component) == 1 end)

      # Check that isolated component has only node 6
      isolated_component_ids = Enum.map(isolated_component, fn node -> node.id end)

      assert "6" in isolated_component_ids
    end
  end

  describe "graph analysis algorithms" do
    @tag :skip
    test "can calculate PageRank", %{nodes: _nodes, edges: _edges} do
      # Calculate PageRank
      {:ok, ranks} = Store.Algorithm.pagerank()

      # All nodes should have a rank
      assert map_size(ranks) == 5

      # Node 3 should have the highest rank since it's most connected
      assert ranks["3"] > ranks["1"]
      assert ranks["3"] > ranks["2"]
      assert ranks["3"] > ranks["4"]
      assert ranks["3"] > ranks["5"]
    end

    @tag :skip
    test "can find minimum spanning tree", %{nodes: _nodes, edges: _edges} do
      # Find the minimum spanning tree
      {:ok, tree_edges, total_weight} = Store.Algorithm.minimum_spanning_tree()

      # A spanning tree for n nodes should have n-1 edges
      assert length(tree_edges) == 4

      # The total weight should be the sum of the weights of the edges in the tree
      # e3, e2, e4, e6
      expected_weight = 1.0 + 2.0 + 3.0 + 4.0
      assert total_weight == expected_weight

      # Check that all nodes are connected in the tree
      # Get all connected nodes in the tree
      connected_nodes =
        tree_edges
        |> Enum.flat_map(fn edge -> [edge.source, edge.target] end)
        |> Enum.uniq()

      assert length(connected_nodes) == 5
    end
  end
end
