defmodule GraphOS.Store.Node do
  @moduledoc """
  A node in a graph.

  A node has a unique identifier within a graph and can have arbitrary properties.
  """

  use Boundary, deps: []

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id(),
          graph_id: String.t() | nil,
          type: String.t() | nil,
          data: map(),
          metadata: map()
        }

  defstruct [
    :id,
    :graph_id,
    :type,
    data: %{},
    metadata: %{}
  ]

  @doc """
  Creates a new Node struct.

  ## Parameters

  - `attrs` - Attributes for the node

  ## Examples

      iex> GraphOS.Store.Node.new(%{type: "person", data: %{name: "John"}})
      %GraphOS.Store.Node{id: "node_uuid", type: "person", data: %{name: "John"}, metadata: %{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    id = Map.get(attrs, :id) || UUID.uuid4()
    graph_id = Map.get(attrs, :graph_id)
    type = Map.get(attrs, :type)
    data = Map.get(attrs, :data, %{})
    metadata = Map.get(attrs, :metadata, %{})

    %__MODULE__{
      id: id,
      graph_id: graph_id,
      type: type,
      data: data,
      metadata: metadata
    }
  end

  @doc """
  Creates a schema for validating Node attributes.

  ## Examples

      iex> GraphOS.Store.Node.schema()
      %{
        name: :node,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :graph_id, type: :string},
          %{name: :type, type: :string},
          %{name: :data, type: :map, default: %{}},
          %{name: :metadata, type: :map, default: %{}}
        ]
      }
  """
  @spec schema() :: map()
  def schema do
    GraphOS.Schema.define(:node, [
      %{name: :id, type: :string, required: true},
      %{name: :graph_id, type: :string},
      %{name: :type, type: :string},
      %{name: :data, type: :map, default: %{}},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Use this module as a base for a custom node type.

  When used, it will define a new module that inherits from GraphOS.Store.Node.

  ## Options

  - `:graph` - The graph to use for this node type
  - `:schema` - The schema to use for this node type

  ## Examples

      defmodule MyApp.User do
        use GraphOS.Store.Node,
          graph: MyApp.Graph,
          schema: MyUserSchema

        # Custom functions for this node type
        def set_name(user, name) do
          GraphOS.Store.update(__MODULE__, %{id: user.id, data: %{name: name}})
        end
      end
  """
  defmacro __using__(opts) do
    quote do
      import GraphOS.Store.Node, only: [schema: 0]

      @graph unquote(opts[:graph])
      @schema_module unquote(opts[:schema])

      def graph, do: @graph

      def schema do
        if @schema_module do
          @schema_module.schema()
        else
          GraphOS.Store.Node.schema()
        end
      end
    end
  end
end
