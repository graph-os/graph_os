defmodule GraphOS.Store.Schema.MinimalTest do
  use ExUnit.Case, async: false

  defmodule SimpleSchema do
    def fields do
      [
        %{name: :name, type: :string, required: true},
        %{name: :age, type: :integer, required: true}
      ]
    end

    def proto_definition do
      """
      syntax = "proto3";

      message Simple {
        string name = 1;
        int32 age = 2;
      }
      """
    end

    def proto_field_mapping do
      %{
        "name" => :name,
        "age" => :age
      }
    end

    def validate(data) when is_map(data) do
      # Direct validation logic without depending on other functions
      cond do
        not is_map(data) ->
          {:error, "Expected a map"}

        Map.has_key?(data, :age) and not is_integer(data.age) ->
          {:error, "Invalid type for field age: expected :integer"}

        Map.has_key?(data, :age) and data.age < 0 ->
          {:error, "Age must be non-negative"}

        true ->
          {:ok, data}
      end
    end
  end

  alias GraphOS.Store.Schema

  test "schema validation works" do
    # Define schema using the new API
    schema = Schema.define(:simple, SimpleSchema.fields())

    # Test valid data
    valid_data = %{name: "Test", age: 30}
    assert {:ok, _} = Schema.validate(schema, valid_data)

    # Test invalid type
    invalid_type = %{name: "Test", age: "thirty"}
    assert {:error, _} = Schema.validate(schema, invalid_type)

    # Test missing field
    missing_field = %{name: "Test"}
    assert {:error, "Missing required field: age"} = Schema.validate(schema, missing_field)
  end

  test "schema definition works" do
    schema = Schema.define(:simple, SimpleSchema.fields())

    assert is_map(schema)
    assert schema.name == :simple
    assert is_list(schema.fields)
    assert length(schema.fields) == 2

    name_field = Enum.find(schema.fields, fn field -> field.name == :name end)
    assert name_field.type == :string
    assert name_field.required == true

    age_field = Enum.find(schema.fields, fn field -> field.name == :age end)
    assert age_field.type == :integer
    assert age_field.required == true
  end
end
