defmodule GraphOS.Entity.NodeTest do
  use ExUnit.Case

  alias GraphOS.Entity.Node
  alias GraphOS.Store.Schema

  # Test entity with data_schema implementation
  defmodule TestNode do
    use GraphOS.Entity.Node

    # Define the schema for validating node data
    def data_schema do
      [
        %{name: :name, type: :string, required: true},
        %{name: :value, type: :integer, default: 0}
      ]
    end
  end

  describe "Node entity basics" do
    test "creating a node with required fields" do
      node = Node.new(%{
        id: "test-node",
        type: "test",
        data: %{foo: "bar"}
      })

      assert node.id == "test-node"
      assert node.type == "test"
      assert node.data.foo == "bar"
    end

    test "creating a node generates an ID if not provided" do
      node = Node.new(%{type: "test"})

      assert node.id != nil
      assert is_binary(node.id)
    end

    test "node schema includes all required fields" do
      schema = Node.schema()

      assert schema.name == :node

      # Verify required fields are present
      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :graph_id in field_names
      assert :type in field_names
      assert :data in field_names
      assert :metadata in field_names
    end
  end

  describe "Custom node entity with data_schema" do
    test "creating a node validates data fields" do
      # Create with valid data
      node = TestNode.new(%{
        data: %{name: "Test Node", value: 42}
      })

      assert node.data.name == "Test Node"
      assert node.data.value == 42
    end

    test "schema incorporates data_schema for validation" do
      schema = TestNode.schema()

      # Find the data field in the schema
      data_field = Enum.find(schema.fields, fn field -> field.name == :data end)

      # Verify data schema fields are included
      assert data_field != nil
      assert data_field.schema != nil

      data_schema_names = Enum.map(data_field.schema, & &1.name)
      assert :name in data_schema_names
      assert :value in data_schema_names

      # Verify the name field is required
      name_field = Enum.find(data_field.schema, fn field -> field.name == :name end)
      assert name_field.required == true

      # Verify the value field has a default
      value_field = Enum.find(data_field.schema, fn field -> field.name == :value end)
      assert value_field.default == 0
    end
  end
end
