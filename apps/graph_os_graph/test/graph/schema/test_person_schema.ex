defmodule GraphOS.Store.Schema.TestPersonSchema do
  @moduledoc """
  Test schema for a person using Protocol Buffers as the canonical schema definition.

  This schema is used specifically for the protobuf schema tests to ensure
  isolation from other tests.
  """

  @behaviour GraphOS.Store.SchemaBehaviour

  @impl true
  def fields do
    [
      {:name, :string, [required: true, description: "Person's full name"]},
      {:age, :integer, [required: true, description: "Person's age in years"]},
      {:attributes, :map, [description: "Additional attributes"]},
      {:tags, {:list, :string}, [description: "Tags associated with the person"]}
    ]
  end

  @impl true
  def proto_definition do
    """
    syntax = "proto3";

    message TestPerson {
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

  @impl true
  def introspect do
    %{
      name: "TestPersonSchema",
      description: "Test schema for a person",
      version: "1.0.0",
      proto_definition: proto_definition(),
      proto_field_mapping: proto_field_mapping(),
      fields: fields()
    }
  end
end
