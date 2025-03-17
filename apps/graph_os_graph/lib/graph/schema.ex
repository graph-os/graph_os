defmodule GraphOS.Graph.Schema do
  @moduledoc """
  Schema definitions for graph elements.
  
  Defines a canonical schema format for graph structures that can be transformed
  by protocol adapters into specific formats (Protobuf, JSONSchema, etc).
  
  This module provides:
  1. Schema definition and validation
  2. A standard format for schema introspection
  3. Common type definitions and validations
  4. Support for generating validations from protobuf definitions
  
  Specific schema implementations can be defined in other components like GraphOS.Core
  while adhering to the behavior defined here.
  
  ## Creating a Schema
  
  There are two ways to define schemas:
  
  ### 1. Field-based Schema
  
  ```elixir
  defmodule MyApp.UserSchema do
    @behaviour GraphOS.Graph.SchemaBehaviour
    
    @impl true
    def fields do
      [
        {:name, :string, [required: true]},
        {:email, :string, [required: true]},
        {:age, :integer, []}
      ]
    end
  end
  ```
  
  ### 2. Protobuf-based Schema
  
  ```elixir
  defmodule MyApp.UserSchema do
    @behaviour GraphOS.Graph.SchemaBehaviour
    
    @impl true
    def proto_definition do
      \"\"\"
      syntax = "proto3";
      
      message User {
        string name = 1;
        string email = 2;
        int32 age = 3;
      }
      \"\"\"
    end
    
    @impl true
    def proto_field_mapping do
      %{
        "name" => :name,
        "email" => :email,
        "age" => :age
      }
    end
  end
  ```
  
  ## Using a Schema
  
  ```elixir
  user_data = %{name: "Alice", email: "alice@example.com", age: 30}
  
  case GraphOS.Graph.Schema.validate(user_data, MyApp.UserSchema) do
    {:ok, valid_data} -> 
      # Data is valid, proceed
      do_something_with(valid_data)
    
    {:error, reason} ->
      # Handle validation error
      IO.puts("Validation failed: \#{reason}")
  end
  ```
  """
  
  # Removed unused aliases
  
  @type field_type :: :string | :integer | :float | :boolean | :map | :list | 
                     {:list, atom()} | {:enum, list()} | :any
  
  @type field_definition :: {atom(), field_type(), keyword()}
  
  @doc """
  Validates data against a schema module.
  
  ## Parameters
    * `data` - The data to validate
    * `schema_module` - Module implementing the GraphOS.Graph.SchemaBehaviour
  
  ## Returns
    * `{:ok, data}` - If validation passes
    * `{:error, reason}` - If validation fails
  
  ## Examples
      iex> GraphOS.Graph.Schema.validate(%{name: "Alice"}, MyApp.PersonSchema)
      {:ok, %{name: "Alice"}}
  """
  @spec validate(map(), module()) :: {:ok, map()} | {:error, term()}
  def validate(data, schema_module) when is_atom(schema_module) and is_map(data) do
    # Check if it's a protobuf-based schema first
    cond do
      function_exported?(schema_module, :validate, 1) ->
        # Use the custom validation function if it exists
        schema_module.validate(data)
        
      function_exported?(schema_module, :proto_definition, 0) ->
        # Use protobuf validation if it has a proto definition
        apply(GraphOS.Graph.Schema.Protobuf, :validate, [data, schema_module])
        
      true ->
        # Fallback to standard field validation
        validate_with_fields(data, get_fields(schema_module))
    end
  end
  
  @doc """
  Gets field definitions from a schema module.
  
  ## Parameters
    * `schema_module` - Module implementing the GraphOS.Graph.SchemaBehaviour
  
  ## Returns
    * List of field definitions `{name, type, opts}`
  
  ## Examples
      iex> GraphOS.Graph.Schema.get_fields(MyApp.PersonSchema)
      [{:name, :string, [required: true]}, {:age, :integer, [required: true]}]
  """
  @spec get_fields(module()) :: [field_definition()]
  def get_fields(schema_module) when is_atom(schema_module) do
    cond do
      function_exported?(schema_module, :fields, 0) ->
        schema_module.fields()
        
      function_exported?(schema_module, :proto_definition, 0) ->
        # Generate fields from protobuf definition
        apply(GraphOS.Graph.Schema.Protobuf, :extract_fields_from_proto, [schema_module.proto_definition()])
        
      true -> 
        []
    end
  end
  
  @doc """
  Gets schema information in a standard format for introspection.
  
  This provides a canonical representation that protocol adapters
  can transform into protocol-specific formats (Protobuf, JSONSchema, etc).
  
  ## Parameters
    * `schema_module` - Module implementing the GraphOS.Graph.SchemaBehaviour
  
  ## Returns
    * Schema definition map with standard fields
  
  ## Examples
      iex> GraphOS.Graph.Schema.introspect(MyApp.PersonSchema)
      %{
        name: "Person",
        fields: [{:name, :string, [required: true]}, ...],
        description: "Represents a person in the system"
      }
  """
  @spec introspect(module()) :: map()
  def introspect(schema_module) when is_atom(schema_module) do
    cond do
      function_exported?(schema_module, :introspect, 0) ->
        schema_module.introspect()
        
      function_exported?(schema_module, :proto_definition, 0) ->
        # Generate introspection from protobuf definition
        %{
          name: schema_module |> to_string() |> String.split(".") |> List.last(),
          fields: get_fields(schema_module),
          description: module_doc(schema_module),
          proto_definition: schema_module.proto_definition(),
          proto_field_mapping: schema_module.proto_field_mapping()
        }
        
      true ->
        %{
          name: schema_module |> to_string() |> String.split(".") |> List.last(),
          fields: get_fields(schema_module),
          description: module_doc(schema_module)
        }
    end
  end
  
  @doc """
  Validates data against field definitions.
  
  ## Parameters
    * `data` - The data to validate
    * `fields` - List of field definitions `{name, type, opts}`
  
  ## Returns
    * `{:ok, data}` - If validation passes
    * `{:error, reason}` - If validation fails
  
  ## Examples
      iex> fields = [{:name, :string, [required: true]}, {:age, :integer, [required: false]}]
      iex> GraphOS.Graph.Schema.validate_with_fields(%{name: "Alice"}, fields)
      {:ok, %{name: "Alice"}}
  """
  @spec validate_with_fields(map(), [field_definition()]) :: {:ok, map()} | {:error, term()}
  def validate_with_fields(data, fields) do
    Enum.reduce_while(fields, {:ok, data}, fn {field_name, field_type, opts}, {:ok, acc} ->
      required = Keyword.get(opts, :required, false)
      
      cond do
        required && !Map.has_key?(data, field_name) && !Map.has_key?(data, to_string(field_name)) ->
          {:halt, {:error, "Missing required field: #{field_name}"}}
          
        Map.has_key?(data, field_name) || Map.has_key?(data, to_string(field_name)) ->
          value = Map.get(data, field_name) || Map.get(data, to_string(field_name))
          
          if validate_type(value, field_type) do
            {:cont, {:ok, acc}}
          else
            {:halt, {:error, "Invalid type for field #{field_name}: expected #{inspect(field_type)}"}}
          end
          
        true ->
          {:cont, {:ok, acc}}
      end
    end)
  end
  
  # Private functions
  
  defp validate_type(_value, :any), do: true
  defp validate_type(value, :string) when is_binary(value), do: true
  defp validate_type(value, :integer) when is_integer(value), do: true
  defp validate_type(value, :float) when is_float(value), do: true
  defp validate_type(value, :boolean) when is_boolean(value), do: true
  defp validate_type(value, :map) when is_map(value), do: true
  defp validate_type(value, :list) when is_list(value), do: true
  defp validate_type(value, {:list, type}) when is_list(value) do
    Enum.all?(value, &validate_type(&1, type))
  end
  defp validate_type(value, {:enum, values}) when is_list(values) do
    Enum.member?(values, value)
  end
  defp validate_type(_, _), do: false
  
  defp module_doc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, :elixir, _, %{"en" => module_doc}, _, _} -> module_doc
      _ -> "No documentation available"
    end
  end
end