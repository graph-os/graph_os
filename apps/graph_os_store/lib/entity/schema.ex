defmodule GraphOS.Entity.Schema do
  @moduledoc """
  Schema definition and validation for GraphOS.Store.

  This module provides functionality for defining and validating
  schemas for GraphOS entities.
  """

  @type field_type ::
          :string
          | :integer
          | :float
          | :boolean
          | :map
          | :list
          | :atom
          | :any
          | {:list, field_type()}
          | {:enum, list(String.t())}

  @doc """
  Defines a new schema.

  ## Parameters

  - `name` - The name of the schema
  - `fields` - The fields of the schema

  ## Examples

      iex> GraphOS.Entity.Schema.define(:user, [
      ...>   %{name: :id, type: :string, required: true},
      ...>   %{name: :name, type: :string, default: "Anonymous"}
      ...> ])
      %{
        name: :user,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :name, type: :string, default: "Anonymous"}
        ]
      }
  """
  @spec define(atom(), list(map())) :: map()
  def define(name, fields) when is_atom(name) and is_list(fields) do
    %{
      name: name,
      fields: fields
    }
  end

  @doc """
  Validates data against a schema.

  ## Parameters

  - `schema` - The schema to validate against
  - `data` - The data to validate

  ## Examples

      iex> schema = GraphOS.Entity.Schema.define(:user, [
      ...>   %{name: :id, type: :string, required: true},
      ...>   %{name: :name, type: :string, default: "Anonymous"}
      ...> ])
      iex> GraphOS.Entity.Schema.validate(schema, %{id: "user1"})
      {:ok, %{id: "user1", name: "Anonymous"}}

      iex> schema = GraphOS.Entity.Schema.define(:user, [
      ...>   %{name: :id, type: :string, required: true},
      ...>   %{name: :name, type: :string}
      ...> ])
      iex> GraphOS.Entity.Schema.validate(schema, %{name: "John"})
      {:error, "Missing required field: id"}
  """
  @spec validate(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def validate(schema, data) do
    # Check required fields
    required_fields = Enum.filter(schema.fields, fn field -> Map.get(field, :required, false) end)
    missing_fields = Enum.filter(required_fields, fn field -> !Map.has_key?(data, field.name) end)

    if Enum.empty?(missing_fields) do
      # Apply default values
      data_with_defaults = apply_defaults(schema, data)

      # Validate types
      case validate_types(schema, data_with_defaults) do
        :ok -> {:ok, data_with_defaults}
        {:error, reason} -> {:error, reason}
      end
    else
      missing_field = hd(missing_fields)
      {:error, "Missing required field: #{missing_field.name}"}
    end
  end

  # Apply default values for fields not present in the data
  defp apply_defaults(schema, data) do
    Enum.reduce(schema.fields, data, fn field, acc ->
      if !Map.has_key?(acc, field.name) && Map.has_key?(field, :default) do
        Map.put(acc, field.name, field.default)
      else
        acc
      end
    end)
  end

  # Validate that field values match their expected types
  defp validate_types(schema, data) do
    result =
      Enum.find_value(schema.fields, fn field ->
        if Map.has_key?(data, field.name) do
          value = Map.get(data, field.name)

          if !type_valid?(field.type, value) do
            # Use inspect for complex types like tuples
            type_str = inspect(field.type)
            value_type = typeof(value)
            "Invalid type for field #{field.name}: expected #{type_str}, got #{value_type}"
          else
            nil
          end
        else
          nil
        end
      end)

    if result, do: {:error, result}, else: :ok
  end

  # Check if a value matches the expected type
  defp type_valid?(:string, value), do: is_binary(value)
  defp type_valid?(:integer, value), do: is_integer(value)
  defp type_valid?(:float, value), do: is_float(value) || is_integer(value)
  defp type_valid?(:boolean, value), do: is_boolean(value)
  defp type_valid?(:map, value), do: is_map(value)
  defp type_valid?(:list, value), do: is_list(value)
  defp type_valid?(:atom, value), do: is_atom(value)
  defp type_valid?(:any, _value), do: true

  defp type_valid?({:list, type}, value) when is_list(value),
    do: Enum.all?(value, &type_valid?(type, &1))

  defp type_valid?({:enum, values}, value) when is_list(values),
    do: value in values

  defp type_valid?(_, _), do: false

  # Get a string representation of a value's type
  defp typeof(value) when is_binary(value), do: "string"
  defp typeof(value) when is_integer(value), do: "integer"
  defp typeof(value) when is_float(value), do: "float"
  defp typeof(value) when is_boolean(value), do: "boolean"
  defp typeof(value) when is_map(value), do: "map"
  defp typeof(value) when is_list(value), do: "list"
  defp typeof(value) when is_atom(value), do: "atom"
  defp typeof(value) when is_tuple(value), do: inspect(value)
  defp typeof(_), do: "unknown"

  @doc """
  Gets the fields from a schema module.

  ## Parameters

  - `schema_module` - Module implementing GraphOS.Entity.SchemaBehaviour

  ## Returns

  - List of fields from the schema module
  """
  @spec get_fields(module()) :: list()
  def get_fields(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :fields, 0) do
      schema_module.fields()
    else
      []
    end
  end
end
