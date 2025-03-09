defmodule GraphOS.Test.Support.SchemaFactory do
  @moduledoc """
  Factory module to generate test data for schema-related tests.
  Provides functions to create schema attributes, tables, and other schema components.
  """

  alias GraphOS.Schema

  @simple_types [:integer, :string, :boolean, :float, :atom]
  @complex_types [:list, :map, :tuple]
  @dynamic_types [:function, :struct]
  @types @simple_types ++ @complex_types ++ @dynamic_types

  # Simple types
  @spec string :: String.t()
  def string, do: "string"

  @spec integer :: integer()
  def integer, do: 1

  @spec boolean :: boolean()
  def boolean, do: true

  @spec float :: float()
  def float, do: 1.0

  @spec atom :: atom()
  def atom, do: :atom

  @doc "Get a value for a given type."
  def value(type), do: apply(__MODULE__, [type])

  def list(types \\ @simple_types) do
    Enum.map(types, fn type -> value(type) end)
  end

  def map(types \\ @simple_types) do
    Enum.reduce(types, %{}, fn type, map -> put(map, type) end)
  end

  def put(list, type) when is_list(list), do: [value(type) | list]
  def put(map, type) when is_map(map), do: Map.put(map, type, value(type))
  def put(map, key, type) when is_map(map), do: Map.put(map, key, value(type))

  def isomorphic_list(length \\ 10, type \\ :integer) do
    Enum.map(1..length, fn _ -> value(type) end)
  end

  def dynamic_list(length \\ 10, types \\ [:integer, :string, :boolean, :float, :atom]) do
    Enum.map(1..length, fn index -> value(Enum.at(types, rem(index, length(types)))) end)
  end
end
