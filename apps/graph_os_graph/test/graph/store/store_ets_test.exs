defmodule GraphOS.Graph.Store.ETSTest do
  use ExUnit.Case

  alias GraphOS.Graph.{Transaction, Operation}
  alias GraphOS.Graph.Store.ETS, as: ETSStore

  setup do
    # Initialize the store before each test
    {:ok, _} = ETSStore.init()
    # Clean up after each test
    on_exit(fn -> ETSStore.close() end)
    :ok
  end

  describe "initialization" do
    test "init creates an ETS table" do
      assert {:ok, %{table: :graph_os_ets_store}} = ETSStore.init()
      assert :ets.info(:graph_os_ets_store) != :undefined
    end

    test "init is idempotent" do
      # First initialization already done in setup
      assert {:ok, %{table: :graph_os_ets_store}} = ETSStore.init()
      # Second initialization should also succeed
      assert {:ok, %{table: :graph_os_ets_store}} = ETSStore.init()
    end

    test "close removes the ETS table" do
      assert :ok = ETSStore.close()
      assert :ets.info(:graph_os_ets_store) == :undefined
      # Re-init for subsequent tests
      {:ok, _} = ETSStore.init()
    end
  end

  describe "node operations" do
    test "create_node creates a new node" do
      # Create node operation
      node_data = %{name: "Test Node", value: 42}
      node_opts = [id: "node-1", key: :test_node]
      operation = Operation.new(:create, :node, node_data, node_opts)

      # Execute operation
      {:ok, node} = ETSStore.handle(operation)

      # Verify node was created
      assert node.id == "node-1"
      assert node.key == :test_node
      assert node.data == node_data
    end

    test "get_node retrieves an existing node" do
      # First create a node
      create_op = Operation.new(:create, :node, %{name: "Test Node"}, [id: "node-1"])
      {:ok, created_node} = ETSStore.handle(create_op)

      # Then try to get it
      get_op = Operation.new(:get, :node, %{}, [id: "node-1"])
      {:ok, retrieved_node} = ETSStore.handle(get_op)

      # Verify the node was retrieved correctly
      assert retrieved_node.id == created_node.id
      assert retrieved_node.data.name == "Test Node"
    end

    test "get_node returns error for non-existent node" do
      get_op = Operation.new(:get, :node, %{}, [id: "non-existent-node"])
      result = ETSStore.handle(get_op)
      assert result == {:error, :node_not_found}
    end

    test "update_node updates an existing node" do
      # First create a node
      create_op = Operation.new(:create, :node, %{name: "Original Name"}, [id: "node-1"])
      {:ok, _} = ETSStore.handle(create_op)

      # Then update it
      update_op = Operation.new(:update, :node, %{name: "Updated Name", new_field: "New Value"}, [id: "node-1"])
      {:ok, updated_node} = ETSStore.handle(update_op)

      # Verify the node was updated
      assert updated_node.data.name == "Updated Name"
      assert updated_node.data.new_field == "New Value"

      # Verify metadata was updated
      assert updated_node.meta.version == 1  # Assuming new nodes start at version 0
    end

    test "update_node returns error for non-existent node" do
      update_op = Operation.new(:update, :node, %{name: "Updated Name"}, [id: "non-existent-node"])
      result = ETSStore.handle(update_op)
      assert result == {:error, :node_not_found}
    end

    test "delete_node removes an existing node" do
      # First create a node
      create_op = Operation.new(:create, :node, %{name: "Test Node"}, [id: "node-1"])
      {:ok, _} = ETSStore.handle(create_op)

      # Then delete it
      delete_op = Operation.new(:delete, :node, %{}, [id: "node-1"])
      {:ok, deleted_id} = ETSStore.handle(delete_op)
      assert deleted_id == "node-1"

      # Verify the node is gone
      get_op = Operation.new(:get, :node, %{}, [id: "node-1"])
      result = ETSStore.handle(get_op)
      assert result == {:error, :node_not_found}
    end
  end

  describe "edge operations" do
    setup do
      # Create two nodes for edge tests
      ETSStore.handle(Operation.new(:create, :node, %{name: "Source Node"}, [id: "source-1"]))
      ETSStore.handle(Operation.new(:create, :node, %{name: "Target Node"}, [id: "target-1"]))
      :ok
    end

    test "create_edge creates a new edge" do
      # Create edge operation
      edge_opts = [id: "edge-1", key: :test_edge, source: "source-1", target: "target-1", weight: 5]
      operation = Operation.new(:create, :edge, %{type: "connection"}, edge_opts)

      # Execute operation
      {:ok, edge} = ETSStore.handle(operation)

      # Verify edge was created
      assert edge.id == "edge-1"
      assert edge.key == :test_edge
      assert edge.source == "source-1"
      assert edge.target == "target-1"
      assert edge.weight == 5
    end

    test "create_edge fails without source or target" do
      # Missing source
      op1 = Operation.new(:create, :edge, %{}, [id: "edge-bad-1", target: "target-1"])
      result1 = ETSStore.handle(op1)
      assert result1 == {:error, :missing_source_or_target}

      # Missing target
      op2 = Operation.new(:create, :edge, %{}, [id: "edge-bad-2", source: "source-1"])
      result2 = ETSStore.handle(op2)
      assert result2 == {:error, :missing_source_or_target}
    end

    test "get_edge retrieves an existing edge" do
      # First create an edge
      create_op = Operation.new(:create, :edge, %{}, [id: "edge-1", source: "source-1", target: "target-1"])
      {:ok, _} = ETSStore.handle(create_op)

      # Then try to get it
      get_op = Operation.new(:get, :edge, %{}, [id: "edge-1"])
      {:ok, edge} = ETSStore.handle(get_op)

      # Verify the edge was retrieved correctly
      assert edge.id == "edge-1"
      assert edge.source == "source-1"
      assert edge.target == "target-1"
    end

    test "update_edge updates an existing edge" do
      # First create an edge
      create_op = Operation.new(:create, :edge, %{}, [id: "edge-1", source: "source-1", target: "target-1", weight: 1])
      {:ok, _} = ETSStore.handle(create_op)

      # Then update it
      update_op = Operation.new(:update, :edge, %{}, [id: "edge-1"])
      {:ok, updated_edge} = ETSStore.handle(update_op)

      # Verify metadata was updated
      assert updated_edge.meta.version == 1  # Assuming new edges start at version 0
    end

    test "delete_edge removes an existing edge" do
      # First create an edge
      create_op = Operation.new(:create, :edge, %{}, [id: "edge-1", source: "source-1", target: "target-1"])
      {:ok, _} = ETSStore.handle(create_op)

      # Then delete it
      delete_op = Operation.new(:delete, :edge, %{}, [id: "edge-1"])
      {:ok, deleted_id} = ETSStore.handle(delete_op)
      assert deleted_id == "edge-1"

      # Verify the edge is gone
      get_op = Operation.new(:get, :edge, %{}, [id: "edge-1"])
      result = ETSStore.handle(get_op)
      assert result == {:error, :edge_not_found}
    end
  end

  describe "transaction execution" do
    test "execute runs multiple operations successfully" do
      # Create a transaction with multiple operations
      store = ETSStore
      tx = Transaction.new(store)

      # Add operations to the transaction
      create_node_op = Operation.new(:create, :node, %{name: "Node in Transaction"}, [id: "tx-node-1"])
      tx = Transaction.add(tx, create_node_op)

      create_node2_op = Operation.new(:create, :node, %{name: "Another Node"}, [id: "tx-node-2"])
      tx = Transaction.add(tx, create_node2_op)

      edge_opts = [id: "tx-edge-1", source: "tx-node-1", target: "tx-node-2"]
      create_edge_op = Operation.new(:create, :edge, %{}, edge_opts)
      tx = Transaction.add(tx, create_edge_op)

      # Execute the transaction
      {:ok, result} = Transaction.commit(tx)

      # Check that all operations succeeded
      assert length(result.results) == 3
      assert Enum.all?(result.results, fn r -> match?({:ok, _}, r) end)

      # Verify the nodes and edge exist
      {:ok, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "tx-node-1"]))
      {:ok, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "tx-node-2"]))
      {:ok, _} = ETSStore.handle(Operation.new(:get, :edge, %{}, [id: "tx-edge-1"]))
    end

    test "execute fails if any operation fails" do
      # Create a transaction with a failing operation
      store = ETSStore
      tx = Transaction.new(store)

      # Add operations to the transaction
      create_node_op = Operation.new(:create, :node, %{name: "Valid Node"}, [id: "fail-node-1"])
      tx = Transaction.add(tx, create_node_op)

      # This will fail because we're trying to update a non-existent node
      update_bad_op = Operation.new(:update, :node, %{}, [id: "non-existent-node"])
      tx = Transaction.add(tx, update_bad_op)

      # Execute the transaction
      result = Transaction.commit(tx)

      # The transaction should fail
      assert match?({:error, _}, result)
    end
  end

  describe "transaction rollback" do
    test "rollback undoes create operations" do
      # Create and execute a transaction
      store = ETSStore
      tx = Transaction.new(store)

      create_node_op = Operation.new(:create, :node, %{name: "Node to Rollback"}, [id: "rollback-node"])
      tx = Transaction.add(tx, create_node_op)

      {:ok, _} = Transaction.commit(tx)

      # Verify the node exists
      {:ok, node} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "rollback-node"]))
      assert node.id == "rollback-node"

      # Now rollback the transaction
      :ok = ETSStore.rollback(tx)

      # Verify the node no longer exists
      result = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "rollback-node"]))
      assert result == {:error, :node_not_found}
    end

    test "rollback handles complex transactions" do
      # Create and execute a transaction with multiple operations
      store = ETSStore
      tx = Transaction.new(store)

      # Create two nodes and connect them
      tx = Transaction.add(tx, Operation.new(:create, :node, %{}, [id: "complex-node-1"]))
      tx = Transaction.add(tx, Operation.new(:create, :node, %{}, [id: "complex-node-2"]))
      edge_opts = [id: "complex-edge", source: "complex-node-1", target: "complex-node-2"]
      tx = Transaction.add(tx, Operation.new(:create, :edge, %{}, edge_opts))

      {:ok, _} = Transaction.commit(tx)

      # Verify all entities exist
      {:ok, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "complex-node-1"]))
      {:ok, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "complex-node-2"]))
      {:ok, _} = ETSStore.handle(Operation.new(:get, :edge, %{}, [id: "complex-edge"]))

      # Rollback the transaction
      :ok = ETSStore.rollback(tx)

      # Verify all entities are gone
      assert {:error, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "complex-node-1"]))
      assert {:error, _} = ETSStore.handle(Operation.new(:get, :node, %{}, [id: "complex-node-2"]))
      assert {:error, _} = ETSStore.handle(Operation.new(:get, :edge, %{}, [id: "complex-edge"]))
    end
  end

  describe "error handling" do
    test "handles unknown operations" do
      # Create an operation with an unknown action
      result = ETSStore.handle(%Operation{action: :unknown_action, entity: :node, data: %{}, opts: []})
      assert match?({:error, {:unknown_operation, :unknown_action, :node}}, result)
    end

    test "handles operations without required parameters" do
      # Missing ID for update
      op1 = Operation.new(:update, :node, %{name: "No ID"}, [])
      result1 = ETSStore.handle(op1)
      assert result1 == {:error, :missing_id}

      # Missing ID for delete
      op2 = Operation.new(:delete, :node, %{}, [])
      result2 = ETSStore.handle(op2)
      assert result2 == {:error, :missing_id}
    end
  end

  # Tests for query-related protocol callbacks
  describe "query protocol callbacks" do
    setup do
      # Create nodes for query tests
      ETSStore.handle(Operation.new(:create, :node, %{name: "Query Node 1", tag: "test"}, [id: "query-1"]))
      ETSStore.handle(Operation.new(:create, :node, %{name: "Query Node 2", tag: "test"}, [id: "query-2"]))
      ETSStore.handle(Operation.new(:create, :edge, %{type: "relates_to"}, [id: "query-edge-1", source: "query-1", target: "query-2"]))
      :ok
    end

    test "query/1 executes a query" do
      # Test basic query functionality
      query_params = %{start_node_id: "query-1"}
      result = ETSStore.query(query_params)

      assert match?({:ok, _}, result)
    end

    test "get_node/1 retrieves a node by ID" do
      # Direct protocol callback test
      {:ok, node} = ETSStore.get_node("query-1")

      assert node.id == "query-1"
      assert node.data.name == "Query Node 1"
    end

    test "get_edge/1 retrieves an edge by ID" do
      # Direct protocol callback test
      {:ok, edge} = ETSStore.get_edge("query-edge-1")

      assert edge.id == "query-edge-1"
      assert edge.source == "query-1"
      assert edge.target == "query-2"
    end

    test "find_nodes_by_properties/1 finds nodes matching properties" do
      # Since nodes store data in the 'data' field, not 'properties',
      # we need to test based on the implementation
      result = ETSStore.find_nodes_by_properties(%{tag: "test"})

      assert match?({:ok, _nodes}, result)
      {:ok, nodes} = result

      # The test may not pass if find_nodes_by_properties looks for properties in a field other than 'data'
      # Let's check the actual length, which may be 0 if implementation differs
      assert length(nodes) > 0
      if length(nodes) > 0 do
        assert Enum.any?(nodes, fn n -> n.id == "query-1" end)
        assert Enum.any?(nodes, fn n -> n.id == "query-2" end)
      end
    end
  end

end
