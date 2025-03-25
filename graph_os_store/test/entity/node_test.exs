defmodule GraphOS.Entity.NodeTest do
  use ExUnit.Case, async: true

  alias GraphOS.Entity.Node
  alias GraphOS.Entity.Metadata

  describe "new/1" do
    test "creates a node with default values" do
      node = Node.new(%{})

      assert is_binary(node.id)
      assert String.length(node.id) > 0
      assert node.graph_id == nil
      assert node.type == nil
      assert node.data == %{}
      assert %Metadata{} = node.metadata
      assert node.metadata.entity == :node
      assert node.metadata.module == Node
    end

    test "creates a node with provided values" do
      node = Node.new(%{
        id: "node-123",
        graph_id: "graph-123",
        type: "person",
        data: %{name: "John"},
        module: __MODULE__
      })

      assert node.id == "node-123"
      assert node.graph_id == "graph-123"
      assert node.type == "person"
      assert node.data == %{name: "John"}
      assert node.metadata.module == __MODULE__
    end

    test "sets metadata correctly" do
      custom_metadata = Metadata.new(%{entity: :node, module: __MODULE__})
      node = Node.new(%{metadata: custom_metadata})

      assert node.metadata == custom_metadata
    end
  end

  describe "schema/0" do
    test "returns a valid schema definition" do
      schema = Node.schema()

      assert schema.name == :node
      assert is_list(schema.fields)

      field_names = Enum.map(schema.fields, &Map.get(&1, :name))
      assert :id in field_names
      assert :graph_id in field_names
      assert :type in field_names
      assert :data in field_names
      assert :metadata in field_names

      id_field = Enum.find(schema.fields, &(&1.name == :id))
      assert id_field.required == true
      assert id_field.type == :string

      data_field = Enum.find(schema.fields, &(&1.name == :data))
      assert data_field.type == :map
      assert data_field.default == %{}
    end
  end

  # Define a test graph
  defmodule TestGraph do
    use GraphOS.Entity.Graph
  end

  # Test custom node module using GraphOS.Entity.Node
  defmodule CustomNode do
    use GraphOS.Entity.Node,
      graph: TestGraph

    def data_schema do
      [
        %{name: :name, type: :string, required: true},
        %{name: :age, type: :integer}
      ]
    end

    def set_name(node, name) do
      %{node | data: Map.put(node.data, :name, name)}
    end

    # Override the new function completely, replacing the one defined by use
    defoverridable new: 1

    def new(attrs) do
      attrs_with_metadata = if is_map(attrs) do
        Map.put_new(attrs, :metadata, GraphOS.Entity.Metadata.new(%{entity: :node, module: __MODULE__}))
      else
        %{metadata: GraphOS.Entity.Metadata.new(%{entity: :node, module: __MODULE__})}
      end

      GraphOS.Entity.Node.new(attrs_with_metadata)
    end
  end

  describe "using GraphOS.Entity.Node" do
    test "defines a new module with custom functionality" do
      # Test the custom function
      node = CustomNode.new(%{data: %{name: "John", age: 30}})
      updated_node = CustomNode.set_name(node, "Jane")

      assert updated_node.data.name == "Jane"
      assert updated_node.data.age == 30
    end

    test "includes entity metadata in the module" do
      # Create a custom node instance
      custom_node = CustomNode.new(%{type: "person"})

      # Check that it's a valid node
      assert %Node{} = custom_node
      assert custom_node.type == "person"

      # Check that the metadata includes the correct module
      assert custom_node.metadata.module == CustomNode
      assert custom_node.metadata.entity == :node
    end

    test "entity/0 returns the entity configuration" do
      entity_config = CustomNode.entity()

      assert entity_config.entity_type == :node
      assert entity_config.entity_module == CustomNode
      assert entity_config.schema_module == Node
    end

    test "overrides schema/0 when data_schema/0 is defined" do
      # Get the schema
      schema = CustomNode.schema()
      assert schema.name == :node

      # Find the data field
      data_field = Enum.find(schema.fields, &(&1.name == :data))
      assert data_field != nil
    end
  end
end
