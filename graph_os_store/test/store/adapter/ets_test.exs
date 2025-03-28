defmodule GraphOS.Store.Adapter.ETSTest do
  use ExUnit.Case, async: false

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS

  # Helper to create a test Node struct
  def create_test_node(attrs) do
    Node.new(attrs)
  end

  # Helper to create a test Edge struct
  def create_test_edge(attrs) do
    Edge.new(attrs)
  end

  # Setup starts a unique store for each test
  setup do
    # Use a unique name for each test store
    store_name = :"test_store_ets_#{:erlang.unique_integer([:positive])}"
    {:ok, _pid} = Store.start_link(name: store_name, adapter: ETS)

    # Ensure the store is stopped when the test finishes, with better error handling
    on_exit(fn -> 
      try do
        Store.stop(store_name)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, %{store_name: store_name}}
  end

  describe "CRUD operations via Store API" do
    test "insert/3 creates an entity", %{store_name: store_name} do
      node = create_test_node(%{id: "test_node", data: %{name: "Test Node"}})

      {:ok, stored_node} = Store.insert(store_name, Node, node)

      assert stored_node.id == "test_node"
      assert stored_node.data.name == "Test Node"
      assert stored_node.metadata.version == 1

      {:ok, retrieved_node} = Store.get(store_name, Node, "test_node")
      assert retrieved_node.id == "test_node"
    end

    test "insert/3 generates ID if not provided", %{store_name: store_name} do
      node = create_test_node(%{data: %{name: "Auto ID Node"}})

      {:ok, stored_node} = Store.insert(store_name, Node, node)

      assert is_binary(stored_node.id)
      assert String.length(stored_node.id) > 10
    end

    test "insert/3 handles edge creation", %{store_name: store_name} do
      node1 = create_test_node(%{id: "node1"})
      node2 = create_test_node(%{id: "node2"})
      {:ok, _} = Store.insert(store_name, Node, node1)
      {:ok, _} = Store.insert(store_name, Node, node2)

      edge_attrs = %{source: "node1", target: "node2", data: %{type: :connects}}
      edge = create_test_edge(edge_attrs)
      {:ok, stored_edge} = Store.insert(store_name, Edge, edge)

      assert is_binary(stored_edge.id)
      assert stored_edge.source == "node1"
      assert stored_edge.target == "node2"
      assert stored_edge.data.type == :connects

      {:ok, retrieved_edge} = Store.get(store_name, Edge, stored_edge.id)
      assert retrieved_edge.id == stored_edge.id
    end

    test "update/3 updates an existing entity", %{store_name: store_name} do
      node = create_test_node(%{id: "update_node", data: %{name: "Original Name"}})
      {:ok, stored_node} = Store.insert(store_name, Node, node)
      assert stored_node.metadata.version == 1

      updated_node = %{stored_node | data: %{name: "Updated Name"}}
      {:ok, updated_stored_node} = Store.update(store_name, Node, updated_node)

      assert updated_stored_node.data.name == "Updated Name"
      assert updated_stored_node.metadata.version == 2

      {:ok, retrieved} = Store.get(store_name, Node, "update_node")
      assert retrieved.data.name == "Updated Name"
      assert retrieved.metadata.version == 2
    end

    test "update/3 fails for non-existent entity", %{store_name: store_name} do
      node = create_test_node(%{id: "non_existent", data: %{name: "Doesn't Exist"}})
      assert {:error, {:not_found, _}} = Store.update(store_name, Node, node)
    end

    test "delete/3 removes an entity", %{store_name: store_name} do
      node = create_test_node(%{id: "delete_node", data: %{name: "Delete Me"}})
      {:ok, _} = Store.insert(store_name, Node, node)

      {:ok, _} = Store.get(store_name, Node, "delete_node")

      :ok = Store.delete(store_name, Node, "delete_node")
      assert {:error, :deleted} = Store.get(store_name, Node, "delete_node")
    end

    test "get/4 retrieves an entity", %{store_name: store_name} do
      node = create_test_node(%{id: "get_node", data: %{name: "Get Node"}})
      {:ok, _} = Store.insert(store_name, Node, node)

      {:ok, retrieved_node} = Store.get(store_name, Node, "get_node")

      assert retrieved_node.id == "get_node"
      assert retrieved_node.data.name == "Get Node"
    end

    test "get/4 returns error for non-existent entity", %{store_name: store_name} do
      assert {:error, :not_found} = Store.get(store_name, Node, "nonexistent")
    end
  end

  describe "querying operations via Store API" do
    setup %{store_name: store_name} do
      nodes_attrs = [
        %{id: "node_1", data: %{category: "A", value: 10}},
        %{id: "node_2", data: %{category: "A", value: 20}},
        %{id: "node_3", data: %{category: "B", value: 30}},
        %{id: "node_4", data: %{category: "B", value: 40}},
        %{id: "node_5", data: %{category: "C", value: 50}}
      ]

      nodes = Enum.map(nodes_attrs, &create_test_node/1)

      for node <- nodes do
        {:ok, _} = Store.insert(store_name, Node, node)
      end

      edge1 = create_test_edge(%{source: "node_1", target: "node_2", type: :link})
      edge2 = create_test_edge(%{source: "node_3", target: "node_4", type: :link})
      {:ok, _} = Store.insert(store_name, Edge, edge1)
      {:ok, _} = Store.insert(store_name, Edge, edge2)

      :ok
    end

    test "all/2 returns all entities of a type", %{store_name: store_name} do
      {:ok, nodes} = Store.all(store_name, Node, %{})
      assert length(nodes) == 5

      {:ok, edges} = Store.all(store_name, Edge, %{})
      assert length(edges) == 2
    end

    test "all/3 with filter returns filtered entities", %{store_name: store_name} do
      filter_a = %{data: %{category: "A"}}
      {:ok, category_a_nodes} = Store.all(store_name, Node, filter_a)

      assert length(category_a_nodes) == 2
      assert Enum.all?(category_a_nodes, fn node -> node.data.category == "A" end)

      filter_val = %{data: %{value: fn v -> v > 30 end}}
      {:ok, high_value_nodes} = Store.all(store_name, Node, filter_val)

      assert length(high_value_nodes) == 2
      assert Enum.all?(high_value_nodes, fn node -> node.data.value > 30 end)
    end
  end

  describe "schema registration" do
    test "register_schema/2 updates the schema", %{store_name: store_name} do
      new_schema = %{
        nodes: %{
          person: %{fields: %{name: :string, age: :integer}},
          location: %{fields: %{name: :string, coordinates: :tuple}}
        },
        edges: %{
          lives_at: %{fields: %{since: :date}},
          works_at: %{}
        }
      }

      :ok = Store.register_schema(store_name, new_schema)
    end
  end
end
