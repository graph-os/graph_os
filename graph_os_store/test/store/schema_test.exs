defmodule GraphOS.Store.SchemaTest do
  use ExUnit.Case, async: true

  alias GraphOS.Store.Schema

  describe "Schema.define/2" do
    test "defines a schema with name and fields" do
      schema = Schema.define(:test_schema, [
        %{name: :id, type: :string, required: true},
        %{name: :count, type: :integer, default: 0}
      ])

      assert schema.name == :test_schema
      assert length(schema.fields) == 2

      id_field = Enum.find(schema.fields, fn f -> f.name == :id end)
      count_field = Enum.find(schema.fields, fn f -> f.name == :count end)

      assert id_field.type == :string
      assert id_field.required == true

      assert count_field.type == :integer
      assert count_field.default == 0
    end
  end

  describe "Schema.validate/2" do
    setup do
      schema = Schema.define(:user, [
        %{name: :id, type: :string, required: true},
        %{name: :name, type: :string, default: "Anonymous"},
        %{name: :age, type: :integer},
        %{name: :active, type: :boolean, default: true},
        %{name: :tags, type: {:list, :string}}
      ])

      {:ok, schema: schema}
    end

    test "validates data with all required fields", %{schema: schema} do
      {:ok, result} = Schema.validate(schema, %{id: "user1", name: "John", age: 30})

      assert result.id == "user1"
      assert result.name == "John"
      assert result.age == 30
      assert result.active == true  # Default value applied
    end

    test "returns error when required field is missing", %{schema: schema} do
      {:error, message} = Schema.validate(schema, %{name: "John"})

      assert message =~ "Missing required field: id"
    end

    test "applies default values", %{schema: schema} do
      {:ok, result} = Schema.validate(schema, %{id: "user1"})

      assert result.id == "user1"
      assert result.name == "Anonymous"
      assert result.active == true
    end

    test "validates field types", %{schema: schema} do
      {:error, message} = Schema.validate(schema, %{id: "user1", age: "thirty"})

      assert message =~ "Invalid type for field age"
    end

    test "validates list field types", %{schema: schema} do
      {:ok, result} = Schema.validate(schema, %{
        id: "user1",
        tags: ["tag1", "tag2"]
      })

      assert result.tags == ["tag1", "tag2"]

      {:error, message} = Schema.validate(schema, %{
        id: "user1",
        tags: ["tag1", 2]
      })

      assert message =~ "Invalid type for field tags"
    end
  end

  describe "Schema.get_fields/1" do
    defmodule TestSchema do
      def fields do
        [
          %{name: :id, type: :string, required: true},
          %{name: :description, type: :string}
        ]
      end
    end

    test "gets fields from a schema module" do
      fields = Schema.get_fields(TestSchema)

      assert length(fields) == 2
      assert Enum.at(fields, 0).name == :id
      assert Enum.at(fields, 1).name == :description
    end

    test "returns empty list for module without fields function" do
      fields = Schema.get_fields(__MODULE__)

      assert fields == []
    end
  end
end
