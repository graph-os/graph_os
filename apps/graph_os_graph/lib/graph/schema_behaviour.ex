defmodule GraphOS.Graph.SchemaBehaviour do
  @moduledoc """
  Behaviour for schema modules in GraphOS.
  
  This behaviour defines the interface that schema modules should implement
  to be compatible with the GraphOS.Graph schema system. Schema modules can be
  defined in any component, as long as they implement this behaviour.
  
  The schema system is designed to:
  1. Provide a standard way to define schemas for graph elements
  2. Enable validation of data against schemas
  3. Support introspection for generating protocol-specific schemas (Protobuf, JSONSchema, etc.)
  
  The schema system now supports Protocol Buffers as the canonical schema definition format,
  allowing for schema validation directly from protobuf definitions and cross-protocol 
  compatibility.
  """
  
  alias GraphOS.Graph.Schema
  
  @doc """
  Returns the fields defined by the schema.
  
  A field is defined as a tuple of {name, type, options}, where:
  - name is an atom representing the field name
  - type is one of the supported types (:string, :integer, etc.)
  - options is a keyword list of options like [required: true]
  
  ## Example
      def fields do
        [
          {:name, :string, [required: true]},
          {:age, :integer, [required: true]},
          {:attributes, :map, []},
          {:tags, {:list, :string}, []}
        ]
      end
  """
  @callback fields() :: [Schema.field_definition()]
  
  @doc """
  Validates the given data against the schema.
  
  Returns `{:ok, data}` if the data is valid, or `{:error, reason}` if it's invalid.
  
  This function is optional. If not implemented, the default implementation from
  GraphOS.Graph.Schema will be used, which validates based on the field definitions.
  
  ## Example
      def validate(data) do
        # Custom validation logic
        if data.age < 0 do
          {:error, "Age must be non-negative"}
        else
          {:ok, data}
        end
      end
  """
  @callback validate(map()) :: {:ok, map()} | {:error, term()}
  
  @doc """
  Returns introspection data for the schema.
  
  This provides metadata about the schema that can be used by protocol adapters
  to generate protocol-specific schemas (Protobuf, JSONSchema, etc.).
  
  This function is optional. If not implemented, the default implementation from
  GraphOS.Graph.Schema will be used, which builds introspection data from the fields.
  
  ## Example
      def introspect do
        %{
          name: "Person",
          fields: fields(),
          description: "Represents a person in the system",
          version: "1.0.0"
        }
      end
  """
  @callback introspect() :: map()
  
  @doc """
  Returns the Protocol Buffer definition for this schema.
  
  This function should return a protobuf schema definition as a string.
  The definition will be used as the canonical type representation for
  cross-protocol compatibility.
  
  ## Example
      def proto_definition do
        \"\"\"
        syntax = "proto3";
        
        message Person {
          string name = 1;
          int32 age = 2;
          map<string, string> attributes = 3;
          repeated string tags = 4;
        }
        \"\"\"
      end
  """
  @callback proto_definition() :: String.t()
  
  @doc """
  Returns the mapping between Protocol Buffer fields and graph schema fields.
  
  This function should return a map with protobuf field names as keys and
  graph field names as values. This mapping will be used to convert between
  protobuf messages and graph data structures.
  
  ## Example
      def proto_field_mapping do
        %{
          "name" => :name,
          "age" => :age, 
          "attributes" => :attributes,
          "tags" => :tags
        }
      end
  """
  @callback proto_field_mapping() :: map()
  
  @optional_callbacks [validate: 1, introspect: 0, proto_definition: 0, proto_field_mapping: 0]
end