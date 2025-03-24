defmodule GraphOS.Store.Edge do
  @moduledoc """
  An edge in a graph.

  An edge represents a relationship between two nodes, defined by
  source and target node IDs.
  """

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id(),
          graph_id: String.t() | nil,
          source: String.t(),
          target: String.t(),
          type: String.t() | nil,
          key: atom() | nil,
          weight: number() | nil,
          data: map(),
          metadata: map()
        }

  defstruct [
    :id,
    :graph_id,
    :source,
    :target,
    :type,
    :key,
    :weight,
    data: %{},
    metadata: %{}
  ]

  @doc """
  Creates a new Edge struct.

  ## Parameters

  - `attrs` - Attributes for the edge

  ## Examples

      iex> GraphOS.Store.Edge.new(%{source: "node1", target: "node2", type: "knows"})
      %GraphOS.Store.Edge{id: "edge_uuid", source: "node1", target: "node2", type: "knows", data: %{}, metadata: %{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    id = Map.get(attrs, :id) || UUID.uuid4()
    graph_id = Map.get(attrs, :graph_id)
    source = Map.get(attrs, :source)
    target = Map.get(attrs, :target)
    type = Map.get(attrs, :type)
    key = Map.get(attrs, :key)
    weight = Map.get(attrs, :weight)
    data = Map.get(attrs, :data, %{})
    metadata = Map.get(attrs, :metadata, %{})

    %__MODULE__{
      id: id,
      graph_id: graph_id,
      source: source,
      target: target,
      type: type,
      key: key,
      weight: weight,
      data: data,
      metadata: metadata
    }
  end

  @doc """
  Creates a schema for validating Edge attributes.

  ## Examples

      iex> GraphOS.Store.Edge.schema()
      %{
        name: :edge,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :graph_id, type: :string},
          %{name: :source, type: :string, required: true},
          %{name: :target, type: :string, required: true},
          %{name: :type, type: :string},
          %{name: :key, type: :atom},
          %{name: :weight, type: :number},
          %{name: :data, type: :map, default: %{}},
          %{name: :metadata, type: :map, default: %{}}
        ]
      }
  """
  @spec schema() :: map()
  def schema do
    GraphOS.Store.Schema.define(:edge, [
      %{name: :id, type: :string, required: true},
      %{name: :graph_id, type: :string},
      %{name: :source, type: :string, required: true},
      %{name: :target, type: :string, required: true},
      %{name: :type, type: :string},
      %{name: :key, type: :atom},
      %{name: :weight, type: :number},
      %{name: :data, type: :map, default: %{}},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Use this module as a base for a custom edge type.

  When used, it will define a new module that inherits from GraphOS.Store.Edge.

  ## Options

  - `:graph` - The graph to use for this edge type
  - `:schema` - The schema to use for this edge type
  - `:source` - The allowed source node type(s)
  - `:target` - The allowed target node type(s)

  ## Examples

      defmodule MyApp.Friendship do
        use GraphOS.Store.Edge,
          graph: MyApp.Graph,
          schema: MyFriendshipSchema,
          source: MyApp.User,
          target: MyApp.User

        # Custom functions for this edge type
        def set_strength(friendship, strength) do
          GraphOS.Store.update(__MODULE__, %{id: friendship.id, data: %{strength: strength}})
        end
      end
  """
  defmacro __using__(opts) do
    quote do
      import GraphOS.Store.Edge, only: [schema: 0]

      @graph unquote(opts[:graph])
      @schema_module unquote(opts[:schema])
      @source unquote(opts[:source])
      @target unquote(opts[:target])

      def graph, do: @graph
      def source, do: @source
      def target, do: @target

      def schema do
        if @schema_module do
          @schema_module.schema()
        else
          GraphOS.Store.Edge.schema()
        end
      end
    end
  end
end
