defmodule GraphOS.GraphContext.Schema.MinimalTest do
  use ExUnit.Case, async: false
  
  defmodule SimpleSchema do
    @behaviour GraphOS.GraphContext.SchemaBehaviour
    
    @impl true
    def fields do
      [
        {:name, :string, [required: true]},
        {:age, :integer, [required: true]}
      ]
    end
    
    @impl true
    def proto_definition do
      """
      syntax = "proto3";
      
      message Simple {
        string name = 1;
        int32 age = 2;
      }
      """
    end
    
    @impl true
    def proto_field_mapping do
      %{
        "name" => :name,
        "age" => :age
      }
    end
    
    @impl true
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
  
  alias GraphOS.GraphContext.Schema
  
  test "schema validation works" do
    # Test valid data
    valid_data = %{name: "Test", age: 30}
    assert {:ok, _} = Schema.validate(valid_data, SimpleSchema)
    
    # Test invalid type
    invalid_type = %{name: "Test", age: "thirty"}
    assert {:error, _} = Schema.validate(invalid_type, SimpleSchema)
    
    # Test negative age
    negative_age = %{name: "Test", age: -5}
    assert {:error, "Age must be non-negative"} = Schema.validate(negative_age, SimpleSchema)
  end
  
  test "schema introspection works" do
    introspection = Schema.introspect(SimpleSchema)
    
    assert is_map(introspection)
    assert introspection.name == "SimpleSchema"
    assert is_binary(introspection.proto_definition)
    assert introspection.proto_definition == SimpleSchema.proto_definition()
    assert is_map(introspection.proto_field_mapping)
    assert introspection.proto_field_mapping == SimpleSchema.proto_field_mapping()
  end
end