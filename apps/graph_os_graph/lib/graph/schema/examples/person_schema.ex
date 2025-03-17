defmodule GraphOS.Graph.Schema.Examples.PersonSchema do
  @moduledoc """
  Example schema for a person using Protocol Buffers as the canonical schema definition.
  
  This schema demonstrates how to use the protobuf-based schema system.
  It defines a simple person schema with name, age, and attributes fields.
  """
  
  @behaviour GraphOS.Graph.SchemaBehaviour
  
  @doc """
  Returns the fields for this schema.
  
  While we're primarily using protobuf definitions, we still need to implement
  this callback for complete SchemaBehaviour compliance.
  """
  @impl true
  def fields do
    [
      {:name, :string, [required: true, description: "Person's full name"]},
      {:age, :integer, [required: true, description: "Person's age in years"]},
      {:attributes, :map, [description: "Additional attributes"]},
      {:tags, {:list, :string}, [description: "Tags associated with the person"]},
      {:address, :map, [description: "Person's address"]},
      {:status, {:enum, [:UNKNOWN, :ACTIVE, :INACTIVE, :PENDING]}, [description: "Person's current status"]}
    ]
  end
  
  @doc """
  Returns the Protocol Buffer definition for this schema.
  
  This is the canonical representation of the schema and is used to generate
  validations and cross-protocol compatibility.
  """
  @impl true
  def proto_definition do
    """
    syntax = "proto3";
    
    // Person message defines a person entity
    message Person {
      string name = 1;          // Person's full name
      int32 age = 2;            // Person's age in years
      map<string, string> attributes = 3;  // Additional attributes
      repeated string tags = 4;  // Tags associated with the person
      
      // Optional nested address
      message Address {
        string street = 1;
        string city = 2;
        string postal_code = 3;
        string country = 4;
      }
      
      Address address = 5;  // Person's address
      
      // Status enum defines the current status of a person
      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
        INACTIVE = 2;
        PENDING = 3;
      }
      
      Status status = 6;  // Person's current status
    }
    """
  end
  
  @doc """
  Returns the mapping between Protocol Buffer fields and schema fields.
  
  This mapping is used to convert between protocol buffer messages and
  Elixir data structures.
  """
  @impl true
  def proto_field_mapping do
    %{
      "name" => :name,
      "age" => :age,
      "attributes" => :attributes,
      "tags" => :tags,
      "address" => :address,
      "status" => :status
    }
  end
  
  @doc """
  Custom validation function for the schema.
  
  This is optional and will be called if defined. It allows for custom
  validation logic beyond what the protobuf schema can express.
  """
  @impl true
  def validate(data) do
    # First perform type validation
    with :ok <- check_type(data) do
      # Then apply custom validations for business rules
      cond do
        Map.has_key?(data, :age) && is_integer(data.age) && data.age < 0 ->
          {:error, "Age must be non-negative"}
          
        Map.has_key?(data, :name) && is_binary(data.name) && String.length(data.name) < 2 ->
          {:error, "Name must be at least 2 characters long"}
          
        true ->
          {:ok, data}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  # Explicit type checking for test purposes
  defp check_type(%{age: age} = _data) when not is_integer(age) do
    {:error, "Invalid type for field age: expected :integer"}
  end
  defp check_type(_data), do: :ok
  
  @doc """
  Returns schema introspection data.
  
  This is optional and provides additional metadata about the schema
  for introspection and documentation purposes.
  """
  @impl true
  def introspect do
    %{
      name: "PersonSchema",
      description: "Schema for representing a person",
      version: "1.0.0",
      proto_definition: proto_definition(),
      proto_field_mapping: proto_field_mapping(),
      fields: fields()
    }
  end
end