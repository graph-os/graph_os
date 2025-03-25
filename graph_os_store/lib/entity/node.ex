defmodule GraphOS.Entity.Node do
  @moduledoc """
  A node in a graph.

  A node has a unique identifier within a graph and can have arbitrary properties.
  """

  alias GraphOS.Entity.Metadata

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id(),
          graph_id: String.t() | nil,
          type: String.t() | nil,
          data: map(),
          metadata: Metadata.t()
        }

  defstruct [
    :id,
    :graph_id,
    :type,
    :metadata,
    :data
  ]

  @doc """
  Creates a new Node struct.

  ## Parameters

  - `attrs` - Attributes for the node

  ## Examples

      iex> GraphOS.Entity.Node.new(%{type: "person", data: %{name: "John"}})
      %GraphOS.Entity.Node{id: "node_uuid", type: "person", data: %{name: "John"}, metadata: %Metadata{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    # Get the module from the attrs or use this module as the default
    module = Map.get(attrs, :module, __MODULE__)

    %__MODULE__{
      id: Map.get(attrs, :id, UUIDv7.generate()),
      graph_id: Map.get(attrs, :graph_id),
      type: Map.get(attrs, :type),
      data: Map.get(attrs, :data, %{}),
      metadata: Map.get(attrs, :metadata, Metadata.new(%{entity: :node, module: module}))
    }
  end

  @doc """
  Creates a schema for validating Node attributes.

  ## Examples

      iex> GraphOS.Entity.Node.schema()
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
    GraphOS.Store.Schema.define(:node, [
      %{name: :id, type: :string, required: true},
      %{name: :graph_id, type: :string},
      %{name: :type, type: :string},
      %{name: :data, type: :map, default: %{}},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Use this module as a base for a custom node type.

  When used, it will define a new module that inherits from GraphOS.Entity.Node.

  ## Options

  - `:graph` - The graph to use for this node type
  - `:schema` - The schema to use for this node type

  ## Examples

      defmodule MyApp.User do
        use GraphOS.Entity.Node,
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
      import GraphOS.Entity.Node, only: [schema: 0]

      # Ensure entity_type is the first item in the keyword list for from_module_opts
      opts_with_type = [entity_type: :node] ++ Keyword.delete(unquote(opts), :entity_type)

      opts_with_modules = Keyword.merge(opts_with_type, [
        entity_module: __MODULE__,
        schema_module: GraphOS.Entity.Node
      ])

      @entity GraphOS.Entity.from_module_opts(opts_with_modules)

      def entity, do: @entity

      # Override schema only if data_schema is defined
      if Module.defines?(__MODULE__, {:data_schema, 0}) do
        def schema do
          node_schema = GraphOS.Entity.Node.schema()

          # Get the data schema fields from this module
          data_fields = data_schema()

          # Update the :data field in the node schema to use our data_schema validation
          updated_fields = Enum.map(node_schema.fields, fn field ->
            if field.name == :data do
              Map.put(field, :schema, data_fields)
            else
              field
            end
          end)

          %{node_schema | fields: updated_fields}
        end
      else
        def schema, do: GraphOS.Entity.Node.schema()
      end

      # Override new to set the module in metadata
      def new(attrs) do
        metadata = Map.get(attrs, :metadata,
          GraphOS.Entity.Metadata.new(%{entity: :node, module: __MODULE__}))

        GraphOS.Entity.Node.new(%{attrs | metadata: metadata})
      end
    end
  end
end
