defmodule GraphOS.Store.Schema.Adapter do
  @moduledoc """
  Utilities for adapting GraphOS schemas to different formats.

  This module provides helpers for protocol adapters to convert
  GraphOS schema definitions to various formats like Protobuf or JSONSchema.
  It serves as a bridge between the canonical schema format and protocol-specific
  representations.

  Note: The actual protocol adapters should be implemented in GraphOS.Protocol,
  following the component boundaries. This module only provides helpers that
  can be used by those adapters.
  """

  alias GraphOS.Store.Schema

  @doc """
  Maps GraphOS schema types to Protobuf types.

  This is a helper for protocol adapters to map GraphOS schema types to their
  corresponding Protobuf types.

  ## Examples
      iex> GraphOS.Store.Schema.Adapter.to_protobuf_type(:string)
      :string

      iex> GraphOS.Store.Schema.Adapter.to_protobuf_type(:integer)
      :int32
  """
  @spec to_protobuf_type(Schema.field_type()) :: atom()
  def to_protobuf_type(:string), do: :string
  def to_protobuf_type(:integer), do: :int32
  def to_protobuf_type(:float), do: :float
  def to_protobuf_type(:boolean), do: :bool
  # Maps are serialized to bytes in protobuf
  def to_protobuf_type(:map), do: :bytes
  # Generic repeated field
  def to_protobuf_type(:list), do: :repeated
  def to_protobuf_type({:list, inner_type}), do: {:repeated, to_protobuf_type(inner_type)}
  def to_protobuf_type({:enum, _values}), do: :enum
  # Any is serialized to bytes in protobuf
  def to_protobuf_type(:any), do: :bytes

  @doc """
  Maps Protobuf types to GraphOS schema types.

  This is a helper for protocol adapters to map Protobuf types to their
  corresponding GraphOS schema types.

  ## Examples
      iex> GraphOS.Store.Schema.Adapter.from_protobuf_type(:string)
      :string

      iex> GraphOS.Store.Schema.Adapter.from_protobuf_type(:int32)
      :integer
  """
  @spec from_protobuf_type(atom()) :: Schema.field_type()
  def from_protobuf_type(:string), do: :string
  def from_protobuf_type(:int32), do: :integer
  def from_protobuf_type(:int64), do: :integer
  def from_protobuf_type(:uint32), do: :integer
  def from_protobuf_type(:uint64), do: :integer
  def from_protobuf_type(:sint32), do: :integer
  def from_protobuf_type(:sint64), do: :integer
  def from_protobuf_type(:fixed32), do: :integer
  def from_protobuf_type(:fixed64), do: :integer
  def from_protobuf_type(:sfixed32), do: :integer
  def from_protobuf_type(:sfixed64), do: :integer
  def from_protobuf_type(:float), do: :float
  def from_protobuf_type(:double), do: :float
  def from_protobuf_type(:bool), do: :boolean
  def from_protobuf_type(:bytes), do: :string
  def from_protobuf_type({:repeated, inner_type}), do: {:list, from_protobuf_type(inner_type)}
  def from_protobuf_type(:repeated), do: :list
  # Empty placeholder, actual values should be provided
  def from_protobuf_type(:enum), do: {:enum, []}

  @doc """
  Maps GraphOS schema types to JSONSchema types.

  This is a helper for protocol adapters to map GraphOS schema types to their
  corresponding JSONSchema types.

  ## Examples
      iex> GraphOS.Store.Schema.Adapter.to_json_schema_type(:string)
      "string"

      iex> GraphOS.Store.Schema.Adapter.to_json_schema_type(:integer)
      "integer"
  """
  @spec to_json_schema_type(Schema.field_type()) :: String.t() | map()
  def to_json_schema_type(:string), do: "string"
  def to_json_schema_type(:integer), do: "integer"
  def to_json_schema_type(:float), do: "number"
  def to_json_schema_type(:boolean), do: "boolean"
  def to_json_schema_type(:map), do: "object"
  def to_json_schema_type(:list), do: %{"type" => "array"}

  def to_json_schema_type({:list, inner_type}) do
    %{
      "type" => "array",
      "items" => %{"type" => to_json_schema_type(inner_type)}
    }
  end

  def to_json_schema_type({:enum, values}) do
    %{
      "type" => "string",
      "enum" => values
    }
  end

  # Any type in JSONSchema
  def to_json_schema_type(:any), do: %{}

  @doc """
  Generates a Protobuf message definition from a schema module.

  This is a helper for protocol adapters to generate Protobuf message definitions
  from GraphOS schema modules.

  ## Parameters
    * `schema_module` - Module implementing the GraphOS.Store.SchemaBehaviour

  ## Returns
    * String containing the Protobuf message definition

  ## Examples
      iex> GraphOS.Store.Schema.Adapter.generate_proto_message(MyApp.PersonSchema)
      \"\"\"
      message Person {
        string name = 1;
        int32 age = 2;
      }
      \"\"\"
  """
  @spec generate_proto_message(module()) :: String.t()
  def generate_proto_message(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :proto_definition, 0) do
      # If the schema module already has a proto definition, use that
      schema_module.proto_definition()
    else
      # Otherwise, generate one from the fields
      name = schema_module |> to_string() |> String.split(".") |> List.last()
      fields = Schema.get_fields(schema_module)

      field_defs =
        fields
        |> Enum.with_index(1)
        |> Enum.map(fn {{field_name, field_type, _opts}, index} ->
          proto_type = to_protobuf_type(field_type) |> to_string()
          "  #{proto_type} #{field_name} = #{index};"
        end)
        |> Enum.join("\n")

      """
      message #{name} {
      #{field_defs}
      }
      """
    end
  end

  @doc """
  Converts field options to Protobuf field options.

  This is a helper for protocol adapters to convert GraphOS schema field options
  to their corresponding Protobuf field options.
  """
  @spec field_options_to_protobuf(keyword()) :: keyword()
  def field_options_to_protobuf(options) do
    options
    |> Enum.map(fn
      {:required, true} -> {:required, true}
      {:description, desc} -> {:comment, desc}
      {key, value} -> {key, value}
    end)
    |> Enum.into([])
  end

  @doc """
  Converts field options to JSONSchema field options.

  This is a helper for protocol adapters to convert GraphOS schema field options
  to their corresponding JSONSchema field options.
  """
  @spec field_options_to_json_schema(keyword()) :: map()
  def field_options_to_json_schema(options) do
    options
    |> Enum.map(fn
      {:required, true} -> {"required", true}
      {:description, desc} -> {"description", desc}
      {key, value} -> {to_string(key), value}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Generates a default field mapping for a schema module.

  This is a helper for protocol adapters to generate a default mapping between
  Protobuf field names and GraphOS schema field names.

  ## Parameters
    * `schema_module` - Module implementing the GraphOS.Store.SchemaBehaviour

  ## Returns
    * Map with Protobuf field names as keys and GraphOS field names as values

  ## Examples
      iex> GraphOS.Store.Schema.Adapter.generate_field_mapping(MyApp.PersonSchema)
      %{
        "name" => :name,
        "age" => :age
      }
  """
  @spec generate_field_mapping(module()) :: map()
  def generate_field_mapping(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :proto_field_mapping, 0) do
      # If the schema module already has a field mapping, use that
      schema_module.proto_field_mapping()
    else
      # Otherwise, generate a default one from the fields
      fields = Schema.get_fields(schema_module)

      fields
      |> Enum.map(fn {field_name, _field_type, _opts} ->
        {to_string(field_name), field_name}
      end)
      |> Enum.into(%{})
    end
  end
end
