defmodule GraphOS.Entity.MetadataTest do
  use ExUnit.Case, async: false

  alias GraphOS.Entity.Metadata
  alias GraphOS.Store
  alias GraphOS.Store.Adapter.ETS
  alias GraphOS.Entity.{Node, Edge}

  setup do
    # Use a unique store name for each test run to avoid conflicts
    store_name = :"metadata_test_store_#{System.unique_integer([])}"
    {:ok, _pid} = GraphOS.Store.start_link(name: store_name, adapter: ETS)
    
    # Add safer stop process with error handling
    on_exit(fn -> 
      try do
        GraphOS.Store.stop(store_name)
      catch
        _kind, _value -> :ok
      end
    end)
    
    {:ok, %{store_name: store_name}}
  end

  describe "Metadata basics" do
    test "schema function returns correct structure" do
      schema = Metadata.schema()

      assert schema.name == :metadata

      # Verify all fields are present
      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :entity in field_names
      assert :module in field_names
      assert :created_at in field_names
      assert :updated_at in field_names
      assert :deleted_at in field_names
      assert :version in field_names
      assert :deleted in field_names
    end

    test "deleted?/1 function with metadata struct" do
      # Test explicit true value
      metadata = %Metadata{deleted: true}
      assert Metadata.deleted?(metadata) == true

      # Test explicit false value
      metadata = %Metadata{deleted: false}
      assert Metadata.deleted?(metadata) == false

      # Test nil value (should be false)
      metadata = %Metadata{deleted: nil}
      assert Metadata.deleted?(metadata) == false
    end

    test "deleted?/1 function with entity map" do
      # Test with entity that has metadata
      entity = %{metadata: %Metadata{deleted: true}}
      assert Metadata.deleted?(entity) == true

      # Test with entity that has metadata set to false
      entity = %{metadata: %Metadata{deleted: false}}
      assert Metadata.deleted?(entity) == false

      # Test with entity that has metadata with nil deleted field
      entity = %{metadata: %Metadata{deleted: nil}}
      assert Metadata.deleted?(entity) == false
    end
  end

  describe "Manual metadata handling" do
    test "creating a node with manual metadata", %{store_name: store_name} do
      manual_metadata = %Metadata{
        id: "manual_node_1",
        entity: :node,
        module: Node,
        version: 1,
        deleted: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        deleted_at: nil
      }

      node = %Node{
        id: "manual_node_1",
        data: %{test: "data"},
        metadata: manual_metadata
      }

      {:ok, _} = Store.insert(store_name, Node, node)
      {:ok, stored_node} = Store.get(store_name, Node, "manual_node_1")

      # Compare only the important fields, not the timestamps
      assert stored_node.metadata.id == manual_metadata.id
      assert stored_node.metadata.entity == manual_metadata.entity
      assert stored_node.metadata.module == manual_metadata.module
      assert stored_node.metadata.version == manual_metadata.version
      assert stored_node.metadata.deleted == manual_metadata.deleted
    end

    test "creating an edge with manual metadata", %{store_name: store_name} do
      # First create source and target nodes
      source_node = %Node{id: "source1", data: %{}, metadata: %Metadata{}}
      target_node = %Node{id: "target1", data: %{}, metadata: %Metadata{}}
      {:ok, _} = Store.insert(store_name, Node, source_node)
      {:ok, _} = Store.insert(store_name, Node, target_node)

      manual_metadata = %Metadata{
        id: "manual_edge_1",
        entity: :edge,
        module: Edge,
        version: 1,
        deleted: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        deleted_at: nil
      }

      edge = %Edge{
        id: "manual_edge_1",
        source: "source1",
        target: "target1",
        data: %{},
        metadata: manual_metadata
      }

      {:ok, _} = Store.insert(store_name, Edge, edge)
      {:ok, stored_edge} = Store.get(store_name, Edge, "manual_edge_1")

      # Compare only the important fields, not the timestamps
      assert stored_edge.metadata.id == manual_metadata.id
      assert stored_edge.metadata.entity == manual_metadata.entity
      assert stored_edge.metadata.module == manual_metadata.module
      assert stored_edge.metadata.version == manual_metadata.version
      assert stored_edge.metadata.deleted == manual_metadata.deleted
    end

    test "manually updating metadata on entity updates", %{store_name: store_name} do
      # Insert initial node
      node = %Node{
        id: "update_meta_node",
        data: %{value: 1},
        metadata: %Metadata{
          id: "update_meta_node",
          entity: :node,
          module: Node,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          version: 1,
          deleted: false
        }
      }

      {:ok, _} = Store.insert(store_name, Node, node)

      # Retrieve the node
      {:ok, stored_node} = Store.get(store_name, Node, "update_meta_node")
      
      # Update the node with modified data to trigger metadata update
      updated_node = Map.update!(stored_node, :data, fn data -> Map.put(data, :updated, true) end)
      {:ok, updated_stored_node} = Store.update(store_name, Node, updated_node)

      # Verify the version was incremented automatically
      assert updated_stored_node.metadata.version == 2
      # Verify updated_at was changed
      assert DateTime.compare(updated_stored_node.metadata.updated_at, stored_node.metadata.updated_at) == :gt
    end

    test "manually marking an entity as deleted", %{store_name: store_name} do
      # Insert initial node
      node = %Node{
        id: "deleted_meta_node",
        data: %{value: 1},
        metadata: %Metadata{
          id: "deleted_meta_node",
          entity: :node,
          module: Node,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          version: 1,
          deleted: false
        }
      }

      {:ok, _} = Store.insert(store_name, Node, node)

      # Retrieve the node before deletion
      {:ok, stored_node} = Store.get(store_name, Node, "deleted_meta_node")
      assert stored_node.metadata.deleted == false
      
      # Soft delete the node using the Store.delete function
      :ok = Store.delete(store_name, Node, "deleted_meta_node")

      # Verify normal get returns :deleted error
      assert {:error, :deleted} = Store.get(store_name, Node, "deleted_meta_node")

      # We can't directly access deleted nodes through Store.all since it filters them out,
      # so we'll just verify that the delete operation worked by checking the error
    end
  end
end
