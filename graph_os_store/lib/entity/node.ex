defmodule GraphOS.Entity.Node do
  @moduledoc """
  A node in a graph.

  A node has a unique identifier within a graph and can have arbitrary properties.
  """

  @entity GraphOS.Entity.from_module_opts(
            entity_type: :node,
            entity_module: __MODULE__,
            schema_module: __MODULE__
          )

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
    %__MODULE__{
      id: Map.get(attrs, :id, UUIDv7.generate()),
      graph_id: Map.get(attrs, :graph_id),
      type: Map.get(attrs, :type),
      data: Map.get(attrs, :data, %{}),
      metadata: Map.get(attrs, :metadata, %Metadata{})
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
    GraphOS.Entity.Schema.define(:node, [
      %{name: :id, type: :string, required: true},
      %{name: :graph_id, type: :string},
      %{name: :type, type: :string},
      %{name: :data, type: :map, default: %{}},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Returns the entity configuration for the Node module.
  This is needed by the Store adapter to identify the entity type.
  """
  @spec entity() :: GraphOS.Entity.t()
  def entity, do: @entity

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

      # Define the struct for the using module
      defstruct [
        :id,
        :graph_id,
        :type,
        :metadata,
        :data
      ]

      # Define metadata schema
      @metadata_schema GraphOS.Entity.Metadata.schema()

      # Add module information to options
      @opts_with_modules unquote(opts)
                        |> Keyword.put(:module, __MODULE__)
                        |> Keyword.put(:entity_type, :node)
                        |> Keyword.put(:entity_module, __MODULE__)

      # Create entity configuration
      @entity GraphOS.Entity.from_module_opts(@opts_with_modules)

      def entity, do: @entity
      
      # Define module type spec
      @type t :: %__MODULE__{
        id: GraphOS.Entity.id(),
        graph_id: GraphOS.Entity.id() | nil,
        type: String.t() | nil,
        data: map(),
        metadata: GraphOS.Entity.Metadata.t()
      }

      # Always define schema function, but it can be overridden later
      def schema, do: GraphOS.Entity.Node.schema()

      # Override schema to include data_schema if defined
      if Module.defines?(__MODULE__, {:data_schema, 0}, :def) do
        def schema do
          node_schema = GraphOS.Entity.Node.schema()
          data_fields = data_schema()
          
          # Update fields to include data_schema
          updated_fields = Enum.map(node_schema.fields, fn field ->
            if field.name == :data do
              Map.put(field, :schema, data_fields)
            else
              field
            end
          end)
          
          %{node_schema | fields: updated_fields}
        end
      end

      # Override new to set the module in metadata
      def new(attrs) do
        # Create empty metadata and let the store populate it
        metadata = Map.get(attrs, :metadata, %GraphOS.Entity.Metadata{})
        # Pass to parent new function with metadata
        attrs_with_metadata = Map.put(attrs, :metadata, metadata)

        node = GraphOS.Entity.Node.new(attrs_with_metadata)
        struct(__MODULE__, Map.from_struct(node))
      end

      # Make functions overridable
      defoverridable [new: 1, schema: 0]
    end
  end
end
