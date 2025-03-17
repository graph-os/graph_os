defmodule GraphOS.Graph.Schema.Protobuf do
  @moduledoc """
  Utilities for working with Protocol Buffer schemas in GraphOS.
  
  This module provides functions to work with Protocol Buffer definitions,
  validate data against protobuf schemas, and convert between Protocol Buffer
  and Elixir data structures.
  
  It serves as the foundation for using Protocol Buffers as the canonical
  schema definition format in GraphOS, enabling cross-protocol compatibility
  and type safety.
  """
  
  alias GraphOS.Graph.Schema
  
  @doc """
  Validates data against a protobuf schema definition.
  
  Takes data and a schema module that implements the proto_definition/0 callback,
  and validates that the data conforms to the protobuf schema.
  
  ## Parameters
    * `data` - Map of data to validate
    * `schema_module` - Module implementing proto_definition/0
    
  ## Returns
    * `{:ok, data}` - If validation passes
    * `{:error, reason}` - If validation fails
  
  ## Examples
      iex> GraphOS.Graph.Schema.Protobuf.validate(%{name: "Alice", age: 30}, MyApp.PersonSchema)
      {:ok, %{name: "Alice", age: 30}}
  """
  @spec validate(map(), module()) :: {:ok, map()} | {:error, term()}
  def validate(data, schema_module) when is_map(data) and is_atom(schema_module) do
    # For now, we're implementing a simplified validation
    # In a real implementation, we would parse the proto definition and validate against it
    if function_exported?(schema_module, :proto_definition, 0) do
      validate_with_proto_definition(data, schema_module)
    else
      {:error, "Schema module does not implement proto_definition/0"}
    end
  end
  
  @doc """
  Extracts field definitions from a protobuf schema definition.
  
  Parses a protocol buffer definition string and returns a list of field definitions
  in the GraphOS schema format.
  
  ## Parameters
    * `proto_def` - String containing the protobuf definition
    
  ## Returns
    * List of field definitions in the format `{name, type, options}`
    
  ## Examples
      iex> proto_def = \"\"\"
      ...> syntax = "proto3";
      ...> message Person {
      ...>   string name = 1;
      ...>   int32 age = 2;
      ...> }
      ...> \"\"\"
      iex> GraphOS.Graph.Schema.Protobuf.extract_fields_from_proto(proto_def)
      [{:name, :string, [required: false]}, {:age, :integer, [required: false]}]
  """
  @spec extract_fields_from_proto(String.t()) :: [Schema.field_definition()]
  def extract_fields_from_proto(proto_def) when is_binary(proto_def) do
    # This is a simplified implementation that uses regex to parse the proto definition
    # A complete implementation would use a proper proto parser
    
    # Find all field definitions in the protobuf definition
    ~r/\s+(\w+)\s+(\w+)\s*=\s*(\d+);/
    |> Regex.scan(proto_def)
    |> Enum.map(fn [_, type, name, _number] ->
      {
        String.to_atom(name),
        proto_type_to_schema_type(type),
        [required: false] # proto3 fields are optional by default
      }
    end)
  end
  
  @doc """
  Parses a protobuf enum definition and extracts the values.
  
  ## Parameters
    * `proto_def` - String containing the protobuf definition
    * `enum_name` - Name of the enum to extract
    
  ## Returns
    * List of enum values as atoms
    
  ## Examples
      iex> proto_def = \"\"\"
      ...> syntax = "proto3";
      ...> enum Color {
      ...>   RED = 0;
      ...>   GREEN = 1;
      ...>   BLUE = 2;
      ...> }
      ...> \"\"\"
      iex> GraphOS.Graph.Schema.Protobuf.extract_enum_values(proto_def, "Color")
      [:RED, :GREEN, :BLUE]
  """
  @spec extract_enum_values(String.t(), String.t()) :: [atom()]
  def extract_enum_values(proto_def, enum_name) when is_binary(proto_def) and is_binary(enum_name) do
    # Extract the enum definition block
    enum_regex = ~r/enum\s+#{Regex.escape(enum_name)}\s*{([^}]*)}/
    case Regex.run(enum_regex, proto_def) do
      [_, enum_block] ->
        # Extract all enum values
        ~r/\s+(\w+)\s*=\s*\d+;/
        |> Regex.scan(enum_block)
        |> Enum.map(fn [_, value] -> String.to_atom(value) end)
      
      nil -> []
    end
  end
  
  @doc """
  Converts a protobuf message to an Elixir map using the field mapping.
  
  ## Parameters
    * `proto_message` - The protobuf message (as a map)
    * `field_mapping` - Map of protobuf field names to schema field names
    
  ## Returns
    * Elixir map with keys converted according to the field mapping
    
  ## Examples
      iex> proto_message = %{"name" => "Alice", "age" => 30}
      iex> field_mapping = %{"name" => :name, "age" => :age}
      iex> GraphOS.Graph.Schema.Protobuf.proto_to_map(proto_message, field_mapping)
      %{name: "Alice", age: 30}
  """
  @spec proto_to_map(map(), map()) :: map()
  def proto_to_map(proto_message, field_mapping) when is_map(proto_message) and is_map(field_mapping) do
    Enum.reduce(proto_message, %{}, fn {k, v}, acc ->
      case Map.get(field_mapping, k) do
        nil -> acc
        mapped_key -> Map.put(acc, mapped_key, v)
      end
    end)
  end
  
  @doc """
  Converts an Elixir map to a protobuf message using the field mapping.
  
  ## Parameters
    * `map` - The Elixir map
    * `field_mapping` - Map of protobuf field names to schema field names
    
  ## Returns
    * Map with keys converted according to the field mapping (proto format)
    
  ## Examples
      iex> map = %{name: "Alice", age: 30}
      iex> field_mapping = %{"name" => :name, "age" => :age}
      iex> GraphOS.Graph.Schema.Protobuf.map_to_proto(map, field_mapping)
      %{"name" => "Alice", "age" => 30}
  """
  @spec map_to_proto(map(), map()) :: map()
  def map_to_proto(map, field_mapping) when is_map(map) and is_map(field_mapping) do
    # Create a reverse mapping from schema fields to proto fields
    reverse_mapping = Enum.reduce(field_mapping, %{}, fn {proto_key, schema_key}, acc ->
      Map.put(acc, schema_key, proto_key)
    end)
    
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      case Map.get(reverse_mapping, k) do
        nil -> acc
        proto_key -> Map.put(acc, proto_key, v)
      end
    end)
  end
  
  # Private functions
  
  defp validate_with_proto_definition(data, schema_module) do
    proto_def = schema_module.proto_definition()
    fields = extract_fields_from_proto(proto_def)
    
    # Validate data against the extracted fields
    Schema.validate_with_fields(data, fields)
  end
  
  defp proto_type_to_schema_type("string"), do: :string
  defp proto_type_to_schema_type("int32"), do: :integer
  defp proto_type_to_schema_type("int64"), do: :integer
  defp proto_type_to_schema_type("uint32"), do: :integer
  defp proto_type_to_schema_type("uint64"), do: :integer
  defp proto_type_to_schema_type("sint32"), do: :integer
  defp proto_type_to_schema_type("sint64"), do: :integer
  defp proto_type_to_schema_type("fixed32"), do: :integer
  defp proto_type_to_schema_type("fixed64"), do: :integer
  defp proto_type_to_schema_type("sfixed32"), do: :integer
  defp proto_type_to_schema_type("sfixed64"), do: :integer
  defp proto_type_to_schema_type("float"), do: :float
  defp proto_type_to_schema_type("double"), do: :float
  defp proto_type_to_schema_type("bool"), do: :boolean
  defp proto_type_to_schema_type("bytes"), do: :string
  defp proto_type_to_schema_type(type) when is_binary(type) do
    # For now, treat custom types (messages, enums) as maps
    # In a real implementation, we'd handle these differently
    :map
  end
end