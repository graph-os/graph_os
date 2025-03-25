defmodule GraphOS.Entity.EdgeTest do
  use ExUnit.Case, async: true

  alias GraphOS.Entity.Edge
  alias GraphOS.Entity.Metadata
  alias GraphOS.Entity.Binding

  describe "new/1" do
    test "creates an edge with default values" do
      edge = Edge.new(%{source: "source-id", target: "target-id"})

      assert is_binary(edge.id)
      assert String.length(edge.id) > 0
      assert edge.graph_id == nil
      assert edge.source == "source-id"
      assert edge.target == "target-id"
      assert edge.key == nil
      assert edge.weight == nil
      assert edge.data == %{}
      assert %Metadata{} = edge.metadata
      assert edge.metadata.entity == :edge
      assert edge.metadata.module == Edge
    end

    test "creates an edge with provided values" do
      edge = Edge.new(%{
        id: "edge-123",
        graph_id: "graph-123",
        source: "source-id",
        target: "target-id",
        key: :knows,
        weight: 0.8,
        data: %{since: "2023-01-01"},
        module: __MODULE__
      })

      assert edge.id == "edge-123"
      assert edge.graph_id == "graph-123"
      assert edge.source == "source-id"
      assert edge.target == "target-id"
      assert edge.key == :knows
      assert edge.weight == 0.8
      assert edge.data == %{since: "2023-01-01"}
      assert edge.metadata.module == Edge
    end

    test "sets metadata correctly" do
      custom_metadata = Metadata.new(%{entity: :edge, module: __MODULE__})
      edge = Edge.new(%{
        source: "source-id",
        target: "target-id",
        metadata: custom_metadata
      })

      assert edge.metadata == custom_metadata
    end
  end

  describe "schema/0" do
    test "returns a valid schema definition" do
      schema = Edge.schema()

      assert schema.name == :edge
      assert is_list(schema.fields)

      field_names = Enum.map(schema.fields, &Map.get(&1, :name))
      assert :id in field_names
      assert :graph_id in field_names
      assert :source in field_names
      assert :target in field_names
      assert :key in field_names
      assert :weight in field_names
      assert :data in field_names
      assert :metadata in field_names

      id_field = Enum.find(schema.fields, &(&1.name == :id))
      assert id_field.required == true
      assert id_field.type == :string

      source_field = Enum.find(schema.fields, &(&1.name == :source))
      assert source_field.required == true
      assert source_field.type == :string

      target_field = Enum.find(schema.fields, &(&1.name == :target))
      assert target_field.required == true
      assert target_field.type == :string

      data_field = Enum.find(schema.fields, &(&1.name == :data))
      assert data_field.type == :map
      assert data_field.default == %{}
    end
  end

  # Define test modules for validation testing
  defmodule TestNodeA do
    use GraphOS.Entity.Node
  end

  defmodule TestNodeB do
    use GraphOS.Entity.Node
  end

  defmodule TestNodeC do
    use GraphOS.Entity.Node
  end

  describe "validate_types/5" do
    test "validates source and target node types against bindings" do
      # Create an edge for testing
      edge = Edge.new(%{source: "source-id", target: "target-id"})

      # Define bindings for different scenarios
      empty_binding = Binding.new(%{})
      include_a_binding = Binding.new(%{include: [TestNodeA]})
      exclude_c_binding = Binding.new(%{exclude: [TestNodeC]})

      # Test validations
      assert :ok = Edge.validate_types(edge, TestNodeA, TestNodeB, empty_binding, empty_binding)
      assert :ok = Edge.validate_types(edge, TestNodeA, TestNodeB, include_a_binding, empty_binding)
      assert :ok = Edge.validate_types(edge, TestNodeA, TestNodeB, empty_binding, exclude_c_binding)
      assert {:error, _} = Edge.validate_types(edge, TestNodeB, TestNodeB, include_a_binding, empty_binding)
      assert {:error, _} = Edge.validate_types(edge, TestNodeA, TestNodeC, empty_binding, exclude_c_binding)
    end
  end

  describe "validate_source_type/3" do
    test "validates source node type" do
      edge = Edge.new(%{source: "source-id", target: "target-id"})

      # Test with include binding
      include_binding = Binding.new(%{include: [TestNodeA]})
      assert :ok = Edge.validate_source_type(edge, TestNodeA, include_binding)
      assert {:error, _} = Edge.validate_source_type(edge, TestNodeB, include_binding)

      # Test with exclude binding
      exclude_binding = Binding.new(%{exclude: [TestNodeC]})
      assert :ok = Edge.validate_source_type(edge, TestNodeA, exclude_binding)
      assert :ok = Edge.validate_source_type(edge, TestNodeB, exclude_binding)
      assert {:error, _} = Edge.validate_source_type(edge, TestNodeC, exclude_binding)

      # Test with both include and exclude
      both_binding = Binding.new(%{include: [TestNodeA, TestNodeB], exclude: [TestNodeB]})
      assert :ok = Edge.validate_source_type(edge, TestNodeA, both_binding)
      assert {:error, _} = Edge.validate_source_type(edge, TestNodeB, both_binding)
      assert {:error, _} = Edge.validate_source_type(edge, TestNodeC, both_binding)
    end
  end

  describe "validate_target_type/3" do
    test "validates target node type" do
      edge = Edge.new(%{source: "source-id", target: "target-id"})

      # Test with include binding
      include_binding = Binding.new(%{include: [TestNodeB]})
      assert :ok = Edge.validate_target_type(edge, TestNodeB, include_binding)
      assert {:error, _} = Edge.validate_target_type(edge, TestNodeA, include_binding)

      # Test with exclude binding
      exclude_binding = Binding.new(%{exclude: [TestNodeC]})
      assert :ok = Edge.validate_target_type(edge, TestNodeA, exclude_binding)
      assert :ok = Edge.validate_target_type(edge, TestNodeB, exclude_binding)
      assert {:error, _} = Edge.validate_target_type(edge, TestNodeC, exclude_binding)

      # Test with both include and exclude
      both_binding = Binding.new(%{include: [TestNodeA, TestNodeB], exclude: [TestNodeB]})
      assert :ok = Edge.validate_target_type(edge, TestNodeA, both_binding)
      assert {:error, _} = Edge.validate_target_type(edge, TestNodeB, both_binding)
      assert {:error, _} = Edge.validate_target_type(edge, TestNodeC, both_binding)
    end
  end

  # Define a test graph
  defmodule TestGraph do
    use GraphOS.Entity.Graph
  end

  # Define a custom edge using Edge module
  defmodule CustomEdge do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: [include: [TestNodeA]],
      target: [include: [TestNodeB]]

    def data_schema do
      [
        %{name: :since, type: :string},
        %{name: :strength, type: :float, default: 1.0}
      ]
    end
  end

  describe "using GraphOS.Entity.Edge" do
    test "defines a new module with bindings" do
      entity = CustomEdge.entity()

      assert entity.entity_type == :edge
      assert entity.entity_module == CustomEdge
      assert entity.schema_module == Edge

      # Check source binding
      assert entity.source.include == [TestNodeA]
      assert entity.source.exclude == []

      # Check target binding
      assert entity.target.include == [TestNodeB]
      assert entity.target.exclude == []
    end

    test "overrides schema/0 when data_schema/0 is defined" do
      # Get the schema
      schema = CustomEdge.schema()
      assert schema.name == :edge

      # Find the data field
      data_field = Enum.find(schema.fields, &(&1.name == :data))
      assert data_field != nil
    end

    test "defines hook callbacks" do
      assert function_exported?(CustomEdge, :before_insert, 2)
      assert function_exported?(CustomEdge, :before_update, 2)
    end
  end
end
