defmodule GraphOS.GraphContext.Schema.ProtobufTest do
  use ExUnit.Case, async: false
  
  # Define the test schema directly in the test to ensure isolation
  defmodule TestSchema do
    @behaviour GraphOS.GraphContext.SchemaBehaviour
    
    @impl true
    def fields do
      [
        {:name, :string, [required: true, description: "Person's name"]},
        {:age, :integer, [required: true, description: "Person's age"]},
        {:attributes, :map, [description: "Additional attributes"]},
        {:tags, {:list, :string}, [description: "Tags for the person"]}
      ]
    end
    
    @impl true
    def proto_definition do
      """
      syntax = "proto3";
      
      message TestSchema {
        string name = 1;
        int32 age = 2;
        map<string, string> attributes = 3;
        repeated string tags = 4;
      }
      """
    end
    
    @impl true
    def proto_field_mapping do
      %{
        "name" => :name,
        "age" => :age,
        "attributes" => :attributes,
        "tags" => :tags
      }
    end
    
    @impl true
    def validate(data) when is_map(data) do
      # Direct validation to avoid relying on other modules
      cond do
        Map.has_key?(data, :age) and not is_integer(data.age) -> 
          {:error, "Invalid type for field age: expected :integer"}
          
        Map.has_key?(data, :age) and data.age < 0 -> 
          {:error, "Age must be non-negative"}
          
        Map.has_key?(data, :name) and String.length(data.name) < 2 ->
          {:error, "Name must be at least 2 characters long"}
          
        true -> 
          {:ok, data}
      end
    end
  end
  
  alias GraphOS.GraphContext.Schema
  alias GraphOS.GraphContext.Schema.Protobuf
  
  describe "Protobuf schema validation" do
    test "validates data against protobuf schema definition" do
      valid_data = %{
        name: "Alice",
        age: 30,
        attributes: %{"hair_color" => "brown", "eye_color" => "blue"},
        tags: ["admin", "user"]
      }
      
      assert {:ok, _} = Schema.validate(valid_data, TestSchema)
    end
    
    test "rejects invalid data" do
      invalid_data = %{
        name: "Bob",
        age: "thirty" # Should be an integer
      }
      
      assert {:error, _} = Schema.validate(invalid_data, TestSchema)
    end
    
    test "applies custom validations" do
      data_with_negative_age = %{
        name: "Charlie",
        age: -5
      }
      
      assert {:error, "Age must be non-negative"} = Schema.validate(data_with_negative_age, TestSchema)
      
      data_with_short_name = %{
        name: "C",
        age: 25
      }
      
      assert {:error, "Name must be at least 2 characters long"} = Schema.validate(data_with_short_name, TestSchema)
    end
  end
  
  describe "Protobuf field extraction" do
    test "extracts fields from protobuf definition" do
      proto_def = """
      syntax = "proto3";
      message Test {
        string name = 1;
        int32 age = 2;
      }
      """
      
      fields = Protobuf.extract_fields_from_proto(proto_def)
      assert Enum.member?(fields, {:name, :string, [required: false]})
      assert Enum.member?(fields, {:age, :integer, [required: false]})
    end
    
    test "extracts enum values" do
      proto_def = """
      syntax = "proto3";
      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
        INACTIVE = 2;
      }
      """
      
      values = Protobuf.extract_enum_values(proto_def, "Status")
      assert values == [:UNKNOWN, :ACTIVE, :INACTIVE]
    end
  end
  
  describe "Protobuf data conversion" do
    test "converts proto message to map" do
      proto_message = %{
        "name" => "Dave",
        "age" => 40,
        "ignored_field" => "should not be included"
      }
      
      field_mapping = %{
        "name" => :name,
        "age" => :age
      }
      
      result = Protobuf.proto_to_map(proto_message, field_mapping)
      assert result == %{name: "Dave", age: 40}
      refute Map.has_key?(result, :ignored_field)
    end
    
    test "converts map to proto message" do
      map = %{
        name: "Eve",
        age: 35,
        ignored_field: "should not be included"
      }
      
      field_mapping = %{
        "name" => :name,
        "age" => :age
      }
      
      result = Protobuf.map_to_proto(map, field_mapping)
      assert result == %{"name" => "Eve", "age" => 35}
      refute Map.has_key?(result, "ignored_field")
    end
  end
  
  describe "Schema introspection with protobuf" do
    test "introspects schema with protobuf definition" do
      introspection = Schema.introspect(TestSchema)
      
      assert introspection.name == "TestSchema"
      assert is_binary(introspection.proto_definition)
      assert is_map(introspection.proto_field_mapping)
    end
  end
end