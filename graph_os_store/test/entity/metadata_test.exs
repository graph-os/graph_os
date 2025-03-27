defmodule GraphOS.Entity.MetadataTest do
  use ExUnit.Case, async: false

  alias GraphOS.Entity.Metadata
  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store

  setup do
    # Initialize a fresh store for each test
    {:ok, _} = Store.init(name: :test_store)
    :ok
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
    test "creating a node with manual metadata" do
      # Create metadata for a node
      metadata = %Metadata{
        entity: :node,
        module: Node,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: 1,
        deleted: false
      }

      # Create a node with this metadata
      node = Node.new(%{
        data: %{name: "Test Node"},
        metadata: metadata
      })

      # Insert the node into the store
      {:ok, stored_node} = Store.insert(Node, node)

      # Verify the metadata was preserved
      assert stored_node.metadata != nil
      assert stored_node.metadata.entity == :node
      assert stored_node.metadata.module == Node
      assert stored_node.metadata.version == 1
      assert stored_node.metadata.deleted == false
    end

    test "creating an edge with manual metadata" do
      # Create source and target nodes first
      source_node = Node.new(%{data: %{name: "Source Node"}})
      target_node = Node.new(%{data: %{name: "Target Node"}})

      {:ok, source} = Store.insert(Node, source_node)
      {:ok, target} = Store.insert(Node, target_node)

      # Create metadata for an edge
      metadata = %Metadata{
        entity: :edge,
        module: Edge,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: 1,
        deleted: false
      }

      # Create an edge with this metadata
      edge = Edge.new(%{
        source: source.id,
        target: target.id,
        metadata: metadata
      })

      # Insert the edge into the store
      {:ok, stored_edge} = Store.insert(Edge, edge)

      # Verify the metadata was preserved
      assert stored_edge.metadata != nil
      assert stored_edge.metadata.entity == :edge
      assert stored_edge.metadata.module == Edge
      assert stored_edge.metadata.version == 1
      assert stored_edge.metadata.deleted == false
    end

    test "manually updating metadata on entity updates" do
      # Create initial node with metadata
      metadata = %Metadata{
        entity: :node,
        module: Node,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: 1,
        deleted: false
      }

      node = Node.new(%{
        data: %{name: "Original Name"},
        metadata: metadata
      })

      {:ok, stored_node} = Store.insert(Node, node)

      # Extract and update the metadata for the update operation
      original_metadata = stored_node.metadata
      updated_metadata = %Metadata{
        original_metadata |
        updated_at: DateTime.utc_now(),
        version: original_metadata.version + 1
      }

      # Update the node with new data and updated metadata
      {:ok, updated_node} = Store.update(Node, %{
        id: stored_node.id,
        data: %{name: "Updated Name"},
        metadata: updated_metadata
      })

      # Verify the metadata was updated correctly
      assert updated_node.metadata.created_at == original_metadata.created_at
      assert updated_node.metadata.updated_at != original_metadata.updated_at
      assert DateTime.compare(updated_node.metadata.updated_at, original_metadata.updated_at) == :gt
      assert updated_node.metadata.version == original_metadata.version + 1
      assert updated_node.metadata.deleted == false
    end

    test "manually marking an entity as deleted" do
      # Create initial node with metadata
      metadata = %Metadata{
        entity: :node,
        module: Node,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: 1,
        deleted: false
      }

      node = Node.new(%{
        data: %{name: "To Be Soft Deleted"},
        metadata: metadata
      })

      {:ok, stored_node} = Store.insert(Node, node)

      # Mark as deleted by updating metadata
      original_metadata = stored_node.metadata
      deleted_metadata = %Metadata{
        original_metadata |
        deleted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: original_metadata.version + 1,
        deleted: true
      }

      # Update the node with deleted metadata
      {:ok, soft_deleted_node} = Store.update(Node, %{
        id: stored_node.id,
        metadata: deleted_metadata
      })

      # Verify the node is marked as deleted
      assert soft_deleted_node.metadata.deleted == true
      assert soft_deleted_node.metadata.deleted_at != nil

      # Verify the deleted?/1 function works correctly
      assert Metadata.deleted?(soft_deleted_node) == true
    end
  end
end
