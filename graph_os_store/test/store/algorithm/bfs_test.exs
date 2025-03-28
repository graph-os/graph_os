defmodule GraphOS.Store.Algorithm.BFSTest do
  use ExUnit.Case

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS
  # alias GraphOS.Store.Algorithm.BFS # Unused alias

  # Create a simple test metadata map for our tests
  def create_test_metadata(module) do
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

    # Create a proper node struct
    %{
      id: id,
      data: data,
      __struct__: Node,
      metadata: create_test_metadata(Node)
    }
  end

  # Helper to create a test Edge as a map
  def create_test_edge(attrs) do
    # Handle the case when a simple tuple {source, target} is passed
    {source, target, attrs} = case attrs do
      {src, tgt} -> {src, tgt, %{}} # Convert tuple to source, target and empty attrs map
      map when is_map(map) -> {Map.get(map, :source), Map.get(map, :target), map}
    end

    id = Map.get(attrs, :id, GraphOS.Entity.generate_id())
    type = Map.get(attrs, :type, :default) # Provide a default type value
    data = Map.get(attrs, :data, %{})

    # If type was provided, add it to the data map
    data = if type, do: Map.put(data, :type, type), else: data

    # Create a map instead of a struct
    %{
      id: id,
      source: source,
      target: target,
      data: data,
      __struct__: Edge
    }
  end

  setup_all do
    # Use a unique store name for each test run
    store_name = String.to_atom("bfs_test_#{System.unique_integer()}")
    # Start the store process
    {:ok, _pid} = GraphOS.Store.start_link(name: store_name, adapter: ETS)
    # Don't stop the store in setup_all, we'll handle that in on_exit of each test

    # Setup initial graph data in the started store
    nodes = for i <- 1..7 do
      node = create_test_node(%{id: "node_#{i}", data: %{name: "Node #{i}"}})
      {:ok, _} = Store.insert(store_name, Node, node)
      node
    end

    # Create edges: forming a more complex structure
    edges = [
      {"node_1", "node_2"},
      {"node_1", "node_3"},
      {"node_2", "node_4"},
      {"node_2", "node_5"},
      {"node_3", "node_6"},
      {"node_3", "node_7"},
      # Add a cycle
      {"node_7", "node_1"},
      # Add an edge with a specific type
      %{id: "edge_typed", source: "node_5", target: "node_6", type: :special}
    ]

    for edge_data <- edges do
      edge = create_test_edge(edge_data)
      {:ok, _} = Store.insert(store_name, Edge, edge)
    end

    # Return the store name in the context for all tests
    {:ok, %{store_name: store_name, nodes: nodes}}
  end

  describe "BFS.execute/2" do
    test "traverses graph in breadth-first order", %{store_name: store_name} do
      # Assuming BFS.execute uses the default store or context is set up elsewhere
      # If BFS needs the store_name, the Store.traverse call needs update
      {:ok, result} = Store.traverse(store_name, :bfs, {"node_1", []})
      node_ids = Enum.map(result, fn node -> node.id end)

      assert Enum.sort(node_ids) == Enum.sort(["node_1", "node_2", "node_3", "node_4", "node_5", "node_6", "node_7"])
    end

    test "respects max_depth option", %{store_name: store_name} do
      {:ok, result} = Store.traverse(store_name, :bfs, {"node_1", [max_depth: 1]})
      node_ids = Enum.map(result, fn node -> node.id end)

      # Should only include node_1 and its direct neighbors (depth 0 and 1)
      assert Enum.sort(node_ids) == Enum.sort(["node_1", "node_2", "node_3"])
    end

    test "handles direction option", %{store_name: store_name} do
      # Test :out direction (default)
      {:ok, result_out} = Store.traverse(store_name, :bfs, {"node_1", [direction: :out]})
      node_ids_out = Enum.map(result_out, fn node -> node.id end)
      assert Enum.sort(node_ids_out) == Enum.sort(["node_1", "node_2", "node_3", "node_4", "node_5", "node_6", "node_7"])

      # Test :in direction (Only node_7 points to node_1)
      {:ok, result_in} = Store.traverse(store_name, :bfs, {"node_1", [direction: :in]})
      node_ids_in = Enum.map(result_in, fn node -> node.id end)
      assert Enum.sort(node_ids_in) == Enum.sort(["node_1", "node_7"]) # BFS starts at node_1, then finds node_7 pointing in
    end

    test "handles both direction option", %{store_name: store_name} do
      # Start from node_4, should traverse inwards to node_2 then outwards
      {:ok, result_both} = Store.traverse(store_name, :bfs, {"node_4", [direction: :both]})
      node_ids_both = Enum.map(result_both, fn node -> node.id end)
      # Should reach all connected nodes regardless of edge direction
      assert Enum.sort(node_ids_both) == Enum.sort(["node_1", "node_2", "node_3", "node_4", "node_5", "node_6", "node_7"])
    end

    test "handles edge_type option", %{store_name: store_name} do
      # Start from node_5, only follow :special edges
      {:ok, result} = Store.traverse(store_name, :bfs, {"node_5", [edge_type: :special]})
      node_ids = Enum.map(result, fn node -> node.id end)

      # Should only find node_5 and node_6 connected by the :special edge
      assert Enum.sort(node_ids) == Enum.sort(["node_5", "node_6"])

      # Test with a type that doesn't exist
      {:ok, result_none} = Store.traverse(store_name, :bfs, {"node_5", [edge_type: :non_existent]})
      assert result_none == [%{id: "node_5"}] # Should only contain the start node
    end

    test "handles cycles in the graph", %{store_name: store_name} do
      # Start from node_1, which is part of a cycle (1 -> ... -> 7 -> 1)
      {:ok, result} = Store.traverse(store_name, :bfs, {"node_1", []})
      node_ids = Enum.map(result, fn node -> node.id end)

      # Ensure all nodes are visited exactly once despite the cycle
      assert Enum.sort(node_ids) == Enum.sort(["node_1", "node_2", "node_3", "node_4", "node_5", "node_6", "node_7"])
      assert length(node_ids) == 7
    end
  end

  # Clean up at the end of all tests
  setup_all context do
    on_exit(fn -> 
      # Try to stop the store if it's still running
      try do
        GraphOS.Store.stop(context.store_name)
      catch
        _kind, _value -> :ok
      end
    end)
    
    :ok
  end
end
