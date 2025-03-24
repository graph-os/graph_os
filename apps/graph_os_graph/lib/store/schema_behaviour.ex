defmodule GraphOS.Store.SchemaBehaviour do
  @moduledoc """
  Behaviour for schema modules in GraphOS.Store.

  Modules implementing this behaviour should define the structure
  of entities in the graph system.
  """

  @doc """
  Returns the service module for the schema.
  """
  @callback service_module() :: module()

  @doc """
  Returns the fields defined by the schema.
  """
  @callback fields() :: list()

  @doc """
  Returns the Protocol Buffer definition for the schema.
  """
  @callback proto_definition() :: String.t()

  @doc """
  Returns the mapping between Protocol Buffer fields and schema fields.
  """
  @callback proto_field_mapping() :: map()

  @doc """
  Introspects the schema.
  """
  @callback introspect() :: map()
end
