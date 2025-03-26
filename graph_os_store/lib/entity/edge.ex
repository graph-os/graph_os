defmodule GraphOS.Entity.Edge do
  @moduledoc """
  An edge in a graph.

  An edge represents a relationship between two nodes, defined by
  source and target node IDs.
  """

  alias GraphOS.Entity.Metadata
  alias GraphOS.Entity.Binding

  @type t :: %__MODULE__{
          id: GraphOS.Entity.id(),
          graph_id: GraphOS.Entity.id() | nil,
          source: GraphOS.Entity.id(),
          target: GraphOS.Entity.id(),
          key: atom() | nil,
          weight: number() | nil,
          data: map(),
          metadata: Metadata.t()
        }

  defstruct [
    :id,
    :graph_id,
    :source,
    :target,
    :key,
    :weight,
    data: %{},
    metadata: %Metadata{}
  ]

  @doc """
  Creates a new Edge struct.

  ## Parameters

  - `attrs` - Attributes for the edge

  ## Examples

      iex> GraphOS.Entity.Edge.new(%{source: "node1", target: "node2", type: "knows"})
      %GraphOS.Entity.Edge{id: "edge_uuid", source: "node1", target: "node2", type: "knows", data: %{}, metadata: %Metadata{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id, UUIDv7.generate()),
      graph_id: Map.get(attrs, :graph_id),
      source: Map.get(attrs, :source),
      target: Map.get(attrs, :target),
      key: Map.get(attrs, :key),
      weight: Map.get(attrs, :weight),
      data: Map.get(attrs, :data, %{}),
      metadata: Map.get(attrs, :metadata, %Metadata{})
    }
  end

  @doc """
  Creates a schema for validating Edge attributes.

  ## Examples

      iex> GraphOS.Entity.Edge.schema()
      %{
        name: :edge,
        fields: [
          %{name: :id, type: :string, required: true},
          %{name: :graph_id, type: :string},
          %{name: :source, type: :string, required: true},
          %{name: :target, type: :string, required: true},
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
      %{name: :key, type: :atom},
      %{name: :weight, type: :number},
      %{name: :data, type: :map, default: %{}},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end

  @doc """
  Validates that the source and target nodes are allowed by the edge's bindings.

  ## Parameters

  - `edge` - The edge to validate
  - `source_module` - The module of the source node
  - `target_module` - The module of the target node
  - `source_binding` - The binding for source nodes
  - `target_binding` - The binding for target nodes

  ## Returns

  - `:ok` if the edge is valid
  - `{:error, reason}` if the edge is invalid
  """
  @spec validate_types(t(), module(), module(), Binding.t(), Binding.t()) :: :ok | {:error, String.t()}
  def validate_types(edge, source_module, target_module, source_binding, target_binding) do
    with :ok <- validate_source_type(edge, source_module, source_binding),
         :ok <- validate_target_type(edge, target_module, target_binding) do
      :ok
    end
  end

  @doc """
  Validates that the source node is allowed by the edge's source binding.

  Follows the binding rules:
  - If include is specified, source module must be in the include list
  - If exclude is specified, source module must not be in the exclude list
  - If both are specified, source must be included AND not excluded
  """
  @spec validate_source_type(t(), module(), Binding.t()) :: :ok | {:error, String.t()}
  def validate_source_type(_edge, source_module, source_binding) do
    if Binding.allowed?(source_binding, source_module) do
      :ok
    else
      cond do
        source_binding.include != [] and source_module not in source_binding.include ->
          {:error, "Source node module #{inspect(source_module)} is not in the allowed include list for this edge type"}
        source_binding.exclude != [] and source_module in source_binding.exclude ->
          {:error, "Source node module #{inspect(source_module)} is explicitly excluded for this edge type"}
        true ->
          {:error, "Source node module #{inspect(source_module)} is not allowed by edge binding"}
      end
    end
  end

  @doc """
  Validates that the target node is allowed by the edge's target binding.

  Follows the binding rules:
  - If include is specified, target module must be in the include list
  - If exclude is specified, target module must not be in the exclude list
  - If both are specified, target must be included AND not excluded
  """
  @spec validate_target_type(t(), module(), Binding.t()) :: :ok | {:error, String.t()}
  def validate_target_type(_edge, target_module, target_binding) do
    if Binding.allowed?(target_binding, target_module) do
      :ok
    else
      cond do
        target_binding.include != [] and target_module not in target_binding.include ->
          {:error, "Target node module #{inspect(target_module)} is not in the allowed include list for this edge type"}
        target_binding.exclude != [] and target_module in target_binding.exclude ->
          {:error, "Target node module #{inspect(target_module)} is explicitly excluded for this edge type"}
        true ->
          {:error, "Target node module #{inspect(target_module)} is not allowed by edge binding"}
      end
    end
  end

  defmacro __using__(opts) do
    quote do
      import GraphOS.Entity.Edge, only: [schema: 0, validate_types: 5, validate_source_type: 3, validate_target_type: 3]

      # Ensure entity_type is set
      opts_with_type = [entity_type: :edge] ++ Keyword.delete(unquote(opts), :entity_type)

      # Add the entity module
      opts_with_modules = Keyword.merge(opts_with_type, [
        entity_module: __MODULE__,
        schema_module: GraphOS.Entity.Edge
      ])

      # Parse source/target binding options
      @source_binding_opts Keyword.get(unquote(opts), :source, [])
      @target_binding_opts Keyword.get(unquote(opts), :target, [])

      # Create binding structs
      @source_binding GraphOS.Entity.Binding.new(@source_binding_opts)
      @target_binding GraphOS.Entity.Binding.new(@target_binding_opts)

      # Create entity configuration
      @entity GraphOS.Entity.from_module_opts(opts_with_modules)

      def entity, do: @entity

      # Override new to set the module in metadata
      def new(attrs) do
        # Create empty metadata and let the store populate it
        metadata = Map.get(attrs, :metadata, %GraphOS.Entity.Metadata{})
        # Pass to parent new function
        attrs_with_metadata = Map.put(attrs, :metadata, metadata)
        GraphOS.Entity.Edge.new(attrs_with_metadata)
      end

      # Override schema only if data_schema is defined
      if Module.defines?(__MODULE__, {:data_schema, 0}) do
        def schema do
          edge_schema = GraphOS.Entity.Edge.schema()

          # Get the data schema fields from this module
          data_fields = data_schema()

          # Update the :data field in the edge schema to use our data_schema validation
          updated_fields = Enum.map(edge_schema.fields, fn field ->
            if field.name == :data do
              Map.put(field, :schema, data_fields)
            else
              field
            end
          end)

          %{edge_schema | fields: updated_fields}
        end
      else
        def schema, do: GraphOS.Entity.Edge.schema()
      end

      @doc """
      Validates the edge type constraints.

      Ensures that:
      - If `include` is defined in a binding, only nodes of those types can be connected
      - If `exclude` is defined in a binding, all node types except those can be connected
      - If both are defined, a node must be included AND not excluded to be connected
      - If neither is defined, all connections are allowed

      Returns:
        - `:ok` if the edge passes validation
        - `{:error, reason}` with a descriptive error message if validation fails
      """
      def validate_edge_types(edge) do
        source_id = edge.source
        target_id = edge.target

        # Get source and target modules from their metadata
        # First, we need to fetch the nodes from the store
        with {:ok, source_node} <- GraphOS.Store.get(GraphOS.Entity.Node, source_id),
             {:ok, target_node} <- GraphOS.Store.get(GraphOS.Entity.Node, target_id) do

          # Extract the module from metadata
          source_module = source_node.metadata.module
          target_module = target_node.metadata.module

          # Validate with the bindings
          source_result = validate_source_type(edge, source_module, @source_binding)
          target_result = validate_target_type(edge, target_module, @target_binding)

          # Both source and target must be valid
          case {source_result, target_result} do
            {:ok, :ok} -> :ok
            {{:error, source_reason}, _} -> {:error, source_reason}
            {_, {:error, target_reason}} -> {:error, target_reason}
          end
        else
          _error -> {:error, "Source or target node not found"}
        end
      end

      # Add callbacks for the Operation.execute/2 function
      def before_insert(edge, _opts) do
        case validate_edge_types(edge) do
          :ok -> {:ok, edge}
          {:error, reason} -> {:error, reason}
        end
      end

      def before_update(edge, _opts) do
        case validate_edge_types(edge) do
          :ok -> {:ok, edge}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
