defmodule GraphOS.Store.Adapter.ETSTest do
  use ExUnit.Case, async: false

  alias GraphOS.Store.Adapter.ETS, as: ETSAdapter
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

  # Setup to ensure the Registry is started
  setup_all do
    # Start the registry if it's not already started
    case Registry.start_link(keys: :unique, name: GraphOS.Store.Registry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      error -> error
    end

    :ok
  end

  # Initialize the ETS tables directly for testing
  setup do
    # Create tables manually
    table_opts = [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ]

    tables = %{
      graph: :graph_os_graphs,
      node: :graph_os_nodes,
      edge: :graph_os_edges,
      metadata: :graph_os_metadata,
      events: :graph_os_events
    }

    # Create each table if it doesn't exist
    Enum.each(tables, fn {_key, name} ->
      case :ets.info(name) do
        :undefined -> :ets.new(name, table_opts)
        _ -> name
      end
    end)

    # Use a unique name for each test
    adapter_name = :"test_adapter_#{:erlang.unique_integer([:positive])}"
    {:ok, _pid} = ETSAdapter.start_link(adapter_name, [])

    {:ok, adapter_name: adapter_name}
  end

  describe "ETS adapter initialization" do
    test "starts and initializes an ETS store", %{adapter_name: name} do
      # The adapter process should be alive
      [{pid, _}] = Registry.lookup(GraphOS.Store.Registry, {ETSAdapter, name})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "re-initializing returns the existing process", %{adapter_name: name} do
      # Look up the existing process
      [{first_pid, _}] = Registry.lookup(GraphOS.Store.Registry, {ETSAdapter, name})

      # Start another process with the same name
      result = ETSAdapter.start_link(name)
      second_pid = case result do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

      # Should return the same PID
      assert first_pid == second_pid
    end
  end

  describe "CRUD operations" do
    test "insert/2 creates an entity", %{adapter_name: _name} do
      node = create_test_node(%{id: "test_node", data: %{name: "Test Node"}})

      {:ok, stored_node} = ETSAdapter.insert(Node, node)

      assert stored_node.id == "test_node"
      assert stored_node.data.name == "Test Node"

      # Verify it's in the store
      {:ok, retrieved_node} = ETSAdapter.get(Node, "test_node")
      assert retrieved_node.id == "test_node"
    end

    test "insert/2 generates ID if not provided", %{adapter_name: _name} do
      node = create_test_node(%{data: %{name: "Auto ID Node"}})

      {:ok, stored_node} = ETSAdapter.insert(Node, node)

      # Should have a generated ID (UUID format)
      assert is_binary(stored_node.id)
      assert String.length(stored_node.id) > 10
    end

    test "update/2 updates an existing entity", %{adapter_name: _name} do
      # Create initial node
      node = create_test_node(%{id: "update_node", data: %{name: "Original Name"}})
      {:ok, stored_node} = ETSAdapter.insert(Node, node)

      # Update the node
      updated_node = %{stored_node | data: %{name: "Updated Name"}}
      {:ok, result} = ETSAdapter.update(Node, updated_node)

      assert result.data.name == "Updated Name"

      # Verify it was updated in the store
      {:ok, retrieved} = ETSAdapter.get(Node, "update_node")
      assert retrieved.data.name == "Updated Name"
    end

    test "update/2 fails for non-existent entity", %{adapter_name: _name} do
      node = create_test_node(%{id: "nonexistent", data: %{name: "Won't Work"}})

      {:error, :not_found} = ETSAdapter.update(Node, node)
    end

    test "delete/2 removes an entity", %{adapter_name: _name} do
      # Create a node to delete
      node = create_test_node(%{id: "delete_node", data: %{name: "Delete Me"}})
      {:ok, _} = ETSAdapter.insert(Node, node)

      # Verify it exists
      {:ok, _} = ETSAdapter.get(Node, "delete_node")

      # Delete it
      :ok = ETSAdapter.delete(Node, "delete_node")

      # Verify it's gone
      {:error, :not_found} = ETSAdapter.get(Node, "delete_node")
    end

    test "get/2 retrieves an entity", %{adapter_name: _name} do
      node = create_test_node(%{id: "get_node", data: %{name: "Get Node"}})
      {:ok, _} = ETSAdapter.insert(Node, node)

      {:ok, retrieved_node} = ETSAdapter.get(Node, "get_node")

      assert retrieved_node.id == "get_node"
      assert retrieved_node.data.name == "Get Node"
    end

    test "get/2 returns error for non-existent entity", %{adapter_name: _name} do
      {:error, :not_found} = ETSAdapter.get(Node, "nonexistent")
    end
  end

  describe "querying operations" do
    setup %{adapter_name: _name} do
      # Insert test nodes with different attributes
      nodes = [
        create_test_node(%{id: "node_1", data: %{category: "A", value: 10}}),
        create_test_node(%{id: "node_2", data: %{category: "A", value: 20}}),
        create_test_node(%{id: "node_3", data: %{category: "B", value: 30}}),
        create_test_node(%{id: "node_4", data: %{category: "B", value: 40}}),
        create_test_node(%{id: "node_5", data: %{category: "C", value: 50}})
      ]

      for node <- nodes do
        {:ok, _} = ETSAdapter.insert(Node, node)
      end

      :ok
    end

    test "all/1 returns all entities of a type", %{adapter_name: _name} do
      {:ok, nodes} = ETSAdapter.all(Node)

      assert length(nodes) == 5
    end

    test "all/2 with filter returns filtered entities", %{adapter_name: _name} do
      # Filter by category A
      {:ok, category_a_nodes} = ETSAdapter.all(Node, %{data: %{category: "A"}})

      assert length(category_a_nodes) == 2
      assert Enum.all?(category_a_nodes, fn node -> node.data.category == "A" end)

      # Filter by value greater than 30
      {:ok, high_value_nodes} = ETSAdapter.all(Node, %{data: %{value: fn v -> v > 30 end}})

      assert length(high_value_nodes) == 2
      assert Enum.all?(high_value_nodes, fn node -> node.data.value > 30 end)
    end

    test "all/3 with pagination options", %{adapter_name: _name} do
      # Get with limit and offset
      {:ok, limited_nodes} = ETSAdapter.all(Node, %{}, limit: 2)

      assert length(limited_nodes) == 2

      # Get second page
      {:ok, second_page} = ETSAdapter.all(Node, %{}, offset: 2, limit: 2)

      assert length(second_page) == 2
      # Make sure we don't have duplicate nodes between pages
      all_ids = Enum.map(limited_nodes ++ second_page, fn node -> node.id end)
      assert length(all_ids) == 4
      assert length(Enum.uniq(all_ids)) == 4
    end

    test "all/3 with sorting option", %{adapter_name: _name} do
      # Sort in ascending order (by ID)
      {:ok, asc_nodes} = ETSAdapter.all(Node, %{}, sort: :asc)

      asc_ids = Enum.map(asc_nodes, fn node -> node.id end)
      assert asc_ids == Enum.sort(asc_ids)

      # Sort in descending order (by ID)
      {:ok, desc_nodes} = ETSAdapter.all(Node, %{}, sort: :desc)

      desc_ids = Enum.map(desc_nodes, fn node -> node.id end)
      assert desc_ids == Enum.sort(desc_ids, :desc)
    end
  end

  describe "graph operations" do
    setup %{adapter_name: _name} do
      # Create a small graph with nodes and edges
      nodes = [
        create_test_node(%{id: "node_1", data: %{name: "Node 1"}}),
        create_test_node(%{id: "node_2", data: %{name: "Node 2"}}),
        create_test_node(%{id: "node_3", data: %{name: "Node 3"}}),
        create_test_node(%{id: "node_4", data: %{name: "Node 4"}}),
        create_test_node(%{id: "node_5", data: %{name: "Node 5"}})
      ]

      for node <- nodes do
        {:ok, _} = ETSAdapter.insert(Node, node)
      end

      edges = [
        create_test_edge(%{id: "edge_1_2", source: "node_1", target: "node_2"}),
        create_test_edge(%{id: "edge_2_3", source: "node_2", target: "node_3"}),
        create_test_edge(%{id: "edge_3_4", source: "node_3", target: "node_4"}),
        create_test_edge(%{id: "edge_4_5", source: "node_4", target: "node_5"}),
        create_test_edge(%{id: "edge_1_3", source: "node_1", target: "node_3"}),
        create_test_edge(%{id: "edge_2_4", source: "node_2", target: "node_4"})
      ]

      for edge <- edges do
        {:ok, _} = ETSAdapter.insert(Edge, edge)
      end

      :ok
    end

    test "traverse/2 with BFS algorithm", %{adapter_name: _name} do
      {:ok, result} = ETSAdapter.traverse(:bfs, {"node_1", []})

      # Extract node IDs from result for easier assertion
      node_ids = Enum.map(result, fn node -> node.id end)

      # First node should be the starting node
      assert List.first(node_ids) == "node_1"

      # All nodes should be reachable from node_1
      assert Enum.sort(node_ids) == ["node_1", "node_2", "node_3", "node_4", "node_5"]

      # BFS order should have direct neighbors first
      # node_1's direct neighbors are node_2 and node_3
      direct_neighbors = Enum.slice(node_ids, 1, 2)
      assert Enum.sort(direct_neighbors) == ["node_2", "node_3"]
    end

    test "traverse/2 with shortest_path algorithm", %{adapter_name: _name} do
      {:ok, path, _distance} = ETSAdapter.traverse(:shortest_path, {"node_1", "node_5", []})

      # Extract node IDs
      path_ids = Enum.map(path, fn node -> node.id end)

      # Path should start and end with the correct nodes
      assert List.first(path_ids) == "node_1"
      assert List.last(path_ids) == "node_5"

      # Path should be connected
      Enum.chunk_every(path_ids, 2, 1, :discard)
      |> Enum.each(fn [source, target] ->
        # For each consecutive pair, there should be an edge
        {:ok, edges} = ETSAdapter.all(Edge, %{source: source, target: target})
        assert length(edges) > 0 ||
               # Or check the reverse direction if edges are undirected
               match?({:ok, [_|_]}, ETSAdapter.all(Edge, %{source: target, target: source}))
      end)
    end

    test "traverse/2 with unsupported algorithm", %{adapter_name: _name} do
      {:error, {:unsupported_algorithm, :invalid_algorithm}} =
        ETSAdapter.traverse(:invalid_algorithm, {})
    end
  end

  describe "schema operations" do
    test "register_schema/2 registers a schema", %{adapter_name: name} do
      schema = %{
        name: :test_entity,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :name, type: :string}
        ]
      }

      assert :ok = ETSAdapter.register_schema(name, schema)
    end
  end
end
