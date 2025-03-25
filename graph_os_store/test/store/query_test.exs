defmodule GraphOS.Store.QueryTest do
  use ExUnit.Case

  alias GraphOS.Store.Query

  describe "get/3" do
    test "creates a valid get query" do
      query = Query.get(:node, "node1")
      assert query.operation == :get
      assert query.module == :node
      assert query.id == "node1"
      assert query.opts == []
    end

    test "creates a get query with options" do
      query = Query.get(:edge, "edge1", include: :data)
      assert query.operation == :get
      assert query.module == :edge
      assert query.id == "edge1"
      assert query.opts == [include: :data]
    end
  end

  describe "list/3" do
    test "creates a valid list query" do
      query = Query.list(:node)
      assert query.operation == :list
      assert query.module == :node
      assert query.filter == %{}
      assert query.opts == []
    end

    test "creates a list query with filter" do
      query = Query.list(:node, %{type: "person"})
      assert query.operation == :list
      assert query.module == :node
      assert query.filter == %{type: "person"}
      assert query.opts == []
    end

    test "creates a list query with filter and options" do
      query = Query.list(:node, %{type: "person"}, limit: 10)
      assert query.operation == :list
      assert query.module == :node
      assert query.filter == %{type: "person"}
      assert query.opts == [limit: 10]
    end
  end

  describe "traverse/2" do
    test "creates a valid traverse query" do
      query = Query.traverse("node1")
      assert query.operation == :traverse
      assert query.start_node_id == "node1"
      assert query.opts == []
    end

    test "creates a traverse query with options" do
      query = Query.traverse("node1", algorithm: :bfs, max_depth: 3)
      assert query.operation == :traverse
      assert query.start_node_id == "node1"
      assert query.opts == [algorithm: :bfs, max_depth: 3]
    end
  end

  describe "shortest_path/3" do
    test "creates a valid shortest path query" do
      query = Query.shortest_path("node1", "node5")
      assert query.operation == :shortest_path
      assert query.start_node_id == "node1"
      assert query.target_node_id == "node5"
      assert query.opts == []
    end

    test "creates a shortest path query with options" do
      query = Query.shortest_path("node1", "node5", weight_property: "distance")
      assert query.operation == :shortest_path
      assert query.start_node_id == "node1"
      assert query.target_node_id == "node5"
      assert query.opts == [weight_property: "distance"]
    end
  end

  describe "connected_components/1" do
    test "creates a valid connected components query" do
      query = Query.connected_components()
      assert query.operation == :connected_components
      assert query.opts == []
    end

    test "creates a connected components query with options" do
      query = Query.connected_components(edge_type: "friend")
      assert query.operation == :connected_components
      assert query.opts == [edge_type: "friend"]
    end
  end

  describe "pagerank/1" do
    test "creates a valid pagerank query" do
      query = Query.pagerank()
      assert query.operation == :pagerank
      assert query.opts == []
    end

    test "creates a pagerank query with options" do
      query = Query.pagerank(iterations: 30, damping: 0.9)
      assert query.operation == :pagerank
      assert query.opts == [iterations: 30, damping: 0.9]
    end
  end

  describe "minimum_spanning_tree/1" do
    test "creates a valid minimum spanning tree query" do
      query = Query.minimum_spanning_tree()
      assert query.operation == :minimum_spanning_tree
      assert query.opts == []
    end

    test "creates a minimum spanning tree query with options" do
      query = Query.minimum_spanning_tree(weight_property: "distance")
      assert query.operation == :minimum_spanning_tree
      assert query.opts == [weight_property: "distance"]
    end
  end

  describe "validate/1" do
    test "validates a valid get query" do
      query = Query.get(:node, "node1")
      assert Query.validate(query) == :ok
    end

    test "validates an invalid get query" do
      query = %GraphOS.Store.Query{operation: :get, module: GraphOS.Entity.Node}
      assert Query.validate(query) == {:error, "Missing required parameter: id for get operation"}
    end

    test "validates a valid traverse query" do
      query = Query.traverse("node1")
      assert Query.validate(query) == :ok
    end

    test "validates an invalid traverse query" do
      query = %GraphOS.Store.Query{operation: :traverse}

      assert Query.validate(query) ==
               {:error, "Missing required parameter: start_node_id for traverse operation"}
    end

    test "validates a valid shortest path query" do
      query = Query.shortest_path("node1", "node5")
      assert Query.validate(query) == :ok
    end

    test "validates an invalid shortest path query" do
      query = %GraphOS.Store.Query{operation: :shortest_path, start_node_id: "node1"}

      assert Query.validate(query) ==
               {:error,
                "Missing required parameters: start_node_id or target_node_id for shortest_path operation"}
    end
  end
end
