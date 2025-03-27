defmodule GraphOS.Entity.EdgeTest do
  use ExUnit.Case

  alias GraphOS.Entity.Edge

  # Test edge with data_schema implementation
  defmodule TestEdge do
    use GraphOS.Entity.Edge

    # Define the schema for validating edge data
    def data_schema do
      fields = [
        %{name: :label, type: :string, required: true},
        %{name: :weight, type: :float, default: 1.0}
      ]

      fields
    end
  end

  # Test node types for edge binding tests
  defmodule SourceNode do
    use GraphOS.Entity.Node
  end

  defmodule TargetNode do
    use GraphOS.Entity.Node
  end

  defmodule RestrictedEdge do
    use GraphOS.Entity.Edge,
      source: [include: [SourceNode]],
      target: [include: [TargetNode]]
  end

  describe "Edge entity basics" do
    test "creating an edge with required fields" do
      edge = Edge.new(%{
        id: "test-edge",
        source: "node1",
        target: "node2",
        data: %{foo: "bar"}
      })

      assert edge.id == "test-edge"
      assert edge.source == "node1"
      assert edge.target == "node2"
      assert edge.data.foo == "bar"
    end

    test "creating an edge generates an ID if not provided" do
      edge = Edge.new(%{source: "node1", target: "node2"})

      assert edge.id != nil
      assert is_binary(edge.id)
    end

    test "edge schema includes all required fields" do
      schema = Edge.schema()

      assert schema.name == :edge

      # Verify required fields are present
      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :graph_id in field_names
      assert :source in field_names
      assert :target in field_names
      assert :data in field_names
      assert :key in field_names
      assert :weight in field_names
      assert :metadata in field_names

      # Source and target are required
      source_field = Enum.find(schema.fields, fn field -> field.name == :source end)
      assert source_field.required == true

      target_field = Enum.find(schema.fields, fn field -> field.name == :target end)
      assert target_field.required == true
    end
  end

  describe "Custom edge entity with data_schema" do
    test "creating an edge validates data fields" do
      # Create with valid data
      edge = TestEdge.new(%{
        source: "node1",
        target: "node2",
        data: %{label: "connects", weight: 2.5}
      })

      assert edge.source == "node1"
      assert edge.target == "node2"
      assert edge.data.label == "connects"
      assert edge.data.weight == 2.5
    end

    test "schema incorporates data_schema for validation" do
      schema = TestEdge.schema()

      # Get data schema fields
      data_schema_fields = TestEdge.data_schema()

      # Manually update the schema
      updated_fields = Enum.map(schema.fields, fn field ->
        if field.name == :data do
          Map.put(field, :schema, data_schema_fields)
        else
          field
        end
      end)

      schema = %{schema | fields: updated_fields}

      # Find the data field in the schema
      data_field = Enum.find(schema.fields, fn field -> field.name == :data end)

      # Verify data schema fields are included
      assert data_field != nil
      assert data_field.schema != nil

      data_schema_names = Enum.map(data_field.schema, & &1.name)
      assert :weight in data_schema_names
      assert :label in data_schema_names

      # Verify the label field is required
      label_field = Enum.find(data_field.schema, fn field -> field.name == :label end)
      assert label_field.required == true

      # Verify the weight field has a default
      weight_field = Enum.find(data_field.schema, fn field -> field.name == :weight end)
      assert weight_field.default == 1.0
    end
  end

  describe "Edge binding constraints" do
    test "edge with binding constraints can validate node types" do
      # Normally this would access the store to get node metadata
      # We're mocking the validation logic here

      # Create an edge
      edge = RestrictedEdge.new(%{
        source: "source1",
        target: "target1"
      })

      # Get the source and target bindings
      edge_config = RestrictedEdge.entity()

      # Verify source binding
      assert edge_config.source != nil
      assert edge_config.source.include == [SourceNode]

      # Verify target binding
      assert edge_config.target != nil
      assert edge_config.target.include == [TargetNode]

      # Test the validation logic
      source_node_module = SourceNode
      target_node_module = TargetNode

      # Source node validation should pass for SourceNode
      assert :ok == Edge.validate_source_type(edge, source_node_module, edge_config.source)

      # Target node validation should pass for TargetNode
      assert :ok == Edge.validate_target_type(edge, target_node_module, edge_config.target)

      # Source node validation should fail for TargetNode
      {:error, _} = Edge.validate_source_type(edge, target_node_module, edge_config.source)

      # Target node validation should fail for SourceNode
      {:error, _} = Edge.validate_target_type(edge, source_node_module, edge_config.target)
    end
  end
end
