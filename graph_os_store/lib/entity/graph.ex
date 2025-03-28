defmodule GraphOS.Entity.Graph do
  @moduledoc """
  A named scope for nodes and edges.

  A Graph is a logical grouping of nodes and edges, while still allowing
  for cross-graph queries and operations.
  """

  alias GraphOS.Entity.Metadata

  @entity GraphOS.Entity.from_module_opts(
            entity_type: :graph,
            entity_module: __MODULE__,
            schema_module: __MODULE__
          )

  @type id :: UUIDv7.t()
  @type t :: %__MODULE__{
          id: id(),
          name: String.t(),
          metadata: Metadata.t()
        }

  defstruct [
    :id,
    :name,
    metadata: %Metadata{}
  ]

  @doc """
  Creates a new Graph struct.

  ## Parameters

  - `attrs` - Attributes for the graph

  ## Examples

      iex> GraphOS.Entity.Graph.new(%{name: "My Graph"})
      %GraphOS.Entity.Graph{id: "graph_uuid", name: "My Graph", metadata: %Metadata{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id, UUIDv7.generate()),
      name: Map.get(attrs, :name),
      metadata: Map.get(attrs, :metadata, %Metadata{})
    }
  end

  @doc """
  Returns the entity configuration for use with the Store adapter.
  """
  @spec entity() :: GraphOS.Entity.t()
  def entity, do: @entity

  @doc """
  Creates a schema for validating Graph attributes.

  ## Examples

      iex> GraphOS.Entity.Graph.schema()
      %{
        name: :graph,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :name, type: :string, default: "Unnamed Graph"},
          %{name: :metadata, type: :map, default: %{}}
        ]
      }
  """
  @spec schema() :: map()
  def schema do
    GraphOS.Entity.Schema.define(:graph, [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, default: ""},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Macro that allows other modules to use the Graph functionality.

  Automatically defines the behavior callbacks for the GraphOS.Entity.Graph.Behaviour.
  """
  defmacro __using__(opts) do
    quote do
      import GraphOS.Entity.Graph, only: [schema: 0]
      
      # Define the struct for modules using this
      defstruct [
        :id,
        :name,
        metadata: %GraphOS.Entity.Metadata{}
      ]

      # Define module type spec
      @type t :: %__MODULE__{
        id: GraphOS.Entity.id(),
        name: String.t() | nil,
        metadata: GraphOS.Entity.Metadata.t()
      }

      @behaviour GraphOS.Entity.Graph.Behaviour

      # Add module information to options
      @opts_with_modules unquote(opts)
                        |> Keyword.put(:module, __MODULE__)
                        |> Keyword.put(:entity_type, :graph)
                        |> Keyword.put(:entity_module, __MODULE__)

      # Create entity configuration
      @entity GraphOS.Entity.from_module_opts(@opts_with_modules)

      def entity, do: @entity

      # Implementation of behaviour callbacks - default versions
      @impl GraphOS.Entity.Graph.Behaviour
      def on_start(_options), do: {:ok, %{}}

      @impl GraphOS.Entity.Graph.Behaviour
      def on_stop(_state), do: {:ok, %{}}

      # Conditionally define schema using data_schema if available
      if Module.defines?(__MODULE__, {:data_schema, 0}, :def) do
        def schema do
          graph_schema = GraphOS.Entity.Graph.schema()
          data_fields = data_schema()
          
          # We want to add a :data field to the schema
          updated_fields = graph_schema.fields ++ [%{name: :data, type: :map, default: %{}, schema: data_fields}]
          %{graph_schema | fields: updated_fields}
        end
        
        # Only make schema overridable when defining it
        defoverridable [schema: 0]
      end

      # Add a proper new function for struct creation
      def new(attrs) do
        %__MODULE__{
          id: Map.get(attrs, :id, UUIDv7.generate()),
          name: Map.get(attrs, :name),
          metadata: Map.get(attrs, :metadata, %GraphOS.Entity.Metadata{})
        }
      end

      # Allow overriding the behaviour callbacks and new function
      defoverridable [on_start: 1, on_stop: 1, new: 1]
    end
  end

  defmodule Behaviour do
    @moduledoc """
    Behaviour for Graph lifecycle hooks.
    """

    @callback on_start(options :: Keyword.t()) ::
                {:ok, state :: map()} | {:error, reason :: term()}
    @callback on_stop(state :: map()) :: {:ok, state :: map()} | {:error, reason :: term()}
  end
end
