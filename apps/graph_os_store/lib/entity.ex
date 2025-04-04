defmodule GraphOS.Entity do
  @moduledoc """
  Utility functions for defining entities.
  """

  use Boundary,
    exports: [
      Graph,
      Graph.Behaviour,
      Node,
      Edge,
      Binding,
      Metadata
    ]

  require Logger

  @type edge_config() :: %__MODULE__{
    entity_module: module(),
    entity_type: :edge,
    graph_module: module(),
    source: GraphOS.Entity.Binding.t(),
    target: GraphOS.Entity.Binding.t(),
    schema_module: module(),
  }

  @type node_config() :: %__MODULE__{
    entity_module: module(),
    entity_type: :node,
    graph_module: module(),
    schema_module: module(),
    source: GraphOS.Entity.Binding.t(),
    target: GraphOS.Entity.Binding.t(),
  }

  @type graph_config() :: %__MODULE__{
    entity_module: module(),
    entity_type: :graph,
    graph_module: module(),
    store_module: module(),
  }

  @type t :: edge_config() | node_config() | graph_config()

  @type id :: UUIDv7.t()

  @typedoc """
  The base type of the entity.
  """
  @type entity_type :: :graph | :node | :edge

  @entity_types [:graph, :node, :edge]

  @doc """
  Checks if the entity type is valid.
  """
  defguard is_entity_type(entity_type) when entity_type in @entity_types

  @doc """
  Returns the entity types as a list.
  """
  @spec entity_types() :: [entity_type()]
  def entity_types, do: @entity_types

  @doc """
  Generates a new ID.
  """
  @spec generate_id() :: id()
  def generate_id do
    UUIDv7.generate()
  end

  defstruct [
    entity_module: nil, # Name of the module
    entity_type: nil, # :graph, :node, :edge
    graph_module: GraphOS.Entity.Graph, # Parent graph module
    schema_module: nil, # Schema module
    source: nil, # Binding for the source module
    target: nil, # Binding for the target module
    store_module: nil, # Only used for graphs.
  ]

  @doc """
  Parses the module options for an entity.
  """
  @spec from_module_opts(Keyword.t()) :: t()
  def from_module_opts(opts) do
    entity_type = Keyword.get(opts, :entity_type)

    case entity_type do
      :graph ->
        cond do
          Keyword.has_key?(opts, :source_binding) ->
            Logger.warning("Graphs do not support source_binding")
          Keyword.has_key?(opts, :target_binding) ->
            Logger.warning("Graphs do not support target_binding")
          Keyword.has_key?(opts, :schema_module) ->
            Logger.warning("Graphs do not support schema_module")
          true ->
            %__MODULE__ {
              entity_module: Keyword.get(opts, :entity_module),
              entity_type: :graph,
              graph_module: Keyword.get(opts, :graph_module, GraphOS.Entity.Graph),
              store_module: Keyword.get(opts, :store_module, GraphOS.Store.Adapter.ETS)
            }
        end

      :node ->
        cond do
          Keyword.has_key?(opts, :store_module) ->
            Logger.warning("Nodes do not support store_module")
          true ->
            %__MODULE__ {
              entity_module: Keyword.get(opts, :entity_module),
              entity_type: :node,
              graph_module: Keyword.get(opts, :graph_module, GraphOS.Entity.Graph),
              schema_module: Keyword.get(opts, :schema_module, GraphOS.Entity.Node),
              source: GraphOS.Entity.Binding.new([]),
              target: GraphOS.Entity.Binding.new([])
            }
        end

      :edge ->
        cond do
          Keyword.has_key?(opts, :store_module) ->
            Logger.warning("Edges do not support store_module")
          true ->
            %__MODULE__ {
              entity_module: Keyword.get(opts, :entity_module),
              entity_type: :edge,
              graph_module: Keyword.get(opts, :graph_module, GraphOS.Entity.Graph),
              source: GraphOS.Entity.Binding.new(Keyword.get(opts, :source, [])),
              target: GraphOS.Entity.Binding.new(Keyword.get(opts, :target, [])),
              schema_module: Keyword.get(opts, :schema_module, GraphOS.Entity.Edge),
            }
        end
    end
  end

  @doc """
  Gets the entity type for a given module.

  This function assumes the module has been created with one of the GraphOS.Entity
  macros (use GraphOS.Entity.Node, use GraphOS.Entity.Edge, use GraphOS.Entity.Graph).

  ## Parameters

  - `module` - The module to get the entity type for

  ## Returns

  - `:node`, `:edge`, or `:graph` if the module is a valid entity
  - `nil` if the module doesn't have an entity() function

  ## Examples

      iex> GraphOS.Entity.get_type(GraphOS.Access.Actor)
      :node

      iex> GraphOS.Entity.get_type(GraphOS.Access.Permission)
      :edge
  """
  @spec get_type(module()) :: entity_type()
  def get_type(module) when is_atom(module) do
    module.entity()
    |> Keyword.get(:entity_type, :error)
  end
end
