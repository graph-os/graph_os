defmodule GraphOS.StoreAlgorithmTest do
  use ExUnit.Case, async: true

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Algorithm

  setup do
    # Ensure we have a clean store for each test
    {:ok, _} = Store.init(name: :test_algorithm)

    # Create a sample graph for testing
    # A -- 1 --> B -- 3 --> D
    # |            ^
    # |            |
    # 2            4
    # |            |
    # v            |
    # C ------------
    {:ok, node_a} = Store.insert(Node, %{id: "A", label: "Node A", data: %{value: 10}})
    {:ok, node_b} = Store.insert(Node, %{id: "B", label: "Node B", data: %{value: 20}})
    {:ok, node_c} = Store.insert(Node, %{id: "C", label: "Node C", data: %{value: 30}})
    {:ok, node_d} = Store.insert(Node, %{id: "D", label: "Node D", data: %{value: 40}})

    {:ok, _} = Store.insert(Edge, %{id: "A-B", source: "A", target: "B", label: "CONNECTS",
                                 data: %{weight: 1.0}})
    {:ok, _} = Store.insert(Edge, %{id: "A-C", source: "A", target: "C", label: "CONNECTS",
                                 data: %{weight: 2.0}})
    {:ok, _} = Store.insert(Edge, %{id: "B-D", source: "B", target: "D", label: "CONNECTS",
                                 data: %{weight: 3.0}})
    {:ok, _} = Store.insert(Edge, %{id: "C-B", source: "C", target: "B", label: "CONNECTS",
                                 data: %{weight: 4.0}})

    # Create a disconnected node
    {:ok, node_e} = Store.insert(Node, %{id: "E", label: "Node E", data: %{value: 50}})

    %{nodes: [node_a, node_b, node_c, node_d, node_e]}
  end

  describe "Store.traverse/2" do
    test "BFS algorithm through Store.traverse" do
      {:ok, nodes} = Store.traverse(:bfs, {"A", [max_depth: 2]})

      node_ids = Enum.map(nodes, & &1.id)
      assert node_ids == ["A", "B", "C"]
    end

    test "Shortest path algorithm through Store.traverse" do
      {:ok, path, weight} = Store.traverse(:shortest_path, {"A", "D", []})

      path_ids = Enum.map(path, & &1.id)
      assert path_ids == ["A", "B", "D"]
      assert weight == 4.0 # 1.0 + 3.0
    end

    test "Connected components algorithm through Store.traverse" do
      {:ok, components} = Store.traverse(:connected_components, [])

      # Should have two components: [A,B,C,D] and [E]
      assert length(components) == 2

      component_sets = components
                       |> Enum.map(fn component ->
                          MapSet.new(Enum.map(component, & &1.id))
                        end)
                       |> MapSet.new()

      assert MapSet.member?(component_sets, MapSet.new(["A", "B", "C", "D"]))
      assert MapSet.member?(component_sets, MapSet.new(["E"]))
    end
  end

  describe "Algorithm module" do
    test "BFS algorithm through dedicated module" do
      {:ok, nodes} = Algorithm.bfs("A", max_depth: 2)

      node_ids = Enum.map(nodes, & &1.id)
      assert node_ids == ["A", "B", "C"]
    end

    test "Shortest path algorithm through dedicated module" do
      {:ok, path, weight} = Algorithm.shortest_path("A", "D")

      path_ids = Enum.map(path, & &1.id)
      assert path_ids == ["A", "B", "D"]
      assert weight == 4.0 # 1.0 + 3.0
    end

    test "Connected components algorithm through dedicated module" do
      {:ok, components} = Algorithm.connected_components()

      # Should have two components: [A,B,C,D] and [E]
      assert length(components) == 2

      component_sets = components
                       |> Enum.map(fn component ->
                          MapSet.new(Enum.map(component, & &1.id))
                        end)
                       |> MapSet.new()

      assert MapSet.member?(component_sets, MapSet.new(["A", "B", "C", "D"]))
      assert MapSet.member?(component_sets, MapSet.new(["E"]))
    end

    test "Page Rank algorithm" do
      {:ok, scores} = Algorithm.page_rank(iterations: 20)

      # Verify all nodes have scores
      assert Map.has_key?(scores, "A")
      assert Map.has_key?(scores, "B")
      assert Map.has_key?(scores, "C")
      assert Map.has_key?(scores, "D")
      assert Map.has_key?(scores, "E")

      # Node with most incoming edges should have higher score
      assert scores["B"] > scores["D"]
      assert scores["B"] > scores["C"]

      # Disconnected node should have lowest score
      assert scores["E"] < scores["A"]
    end

    test "Minimum spanning tree algorithm" do
      {:ok, edges, total_weight} = Algorithm.minimum_spanning_tree()

      # Our MST should include 4 edges (to connect 5 nodes)
      # But since E is disconnected, we'll have 3 edges for the connected component
      edge_ids = Enum.map(edges, & &1.id)
      assert length(edge_ids) == 3

      # The total weight should be the sum of the selected edges
      assert total_weight == 1.0 + 2.0 + 3.0
    end
  end
end
