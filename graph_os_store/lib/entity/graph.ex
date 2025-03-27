defmodule GraphOS.Entity.Graph do
  @moduledoc """
  A named scope for nodes and edges.

  A Graph is a logical grouping of nodes and edges, while still allowing
  for cross-graph queries and operations.
  """

  alias GraphOS.Entity.Metadata

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
  Use this module as a base for a custom graph type.

  When used, it will define a new module that inherits from GraphOS.Entity.Graph and
  implements the required callbacks.

  ## Options

  - `:temp` - Whether this graph is temporary (default: false)

  ## Callbacks

  - `on_start/1` - Called when the graph is started
  - `on_stop/1` - Called when the graph is stopped

  ## Examples

      defmodule MyApp.Graph do
        use GraphOS.Entity.Graph, temp: false

        @impl GraphOS.Entity.Graph
        def on_start(options) do
          # Initialize graph on start
          {:ok, %{started_at: DateTime.utc_now()}}
        end

        @impl GraphOS.Entity.Graph
        def on_stop(state) do
          # Cleanup when graph stops
          {:ok, state}
        end
      end
  """
  defmacro __using__(opts) do
    quote do
      @behaviour GraphOS.Entity.Graph.Behaviour

      @entity unquote(opts)
        |> Keyword.put(:entity_type, :graph)
        |> Keyword.put(:entity_module, __MODULE__)

      @impl GraphOS.Entity.Graph.Behaviour
      def on_start(_options), do: {:ok, %{}}

      @impl GraphOS.Entity.Graph.Behaviour
      def on_stop(_state), do: {:ok, %{}}

      defoverridable on_start: 1, on_stop: 1

      # Override new to set the module in metadata
      def new(attrs) do
        # Create empty metadata and let the store populate it
        metadata = Map.get(attrs, :metadata, %GraphOS.Entity.Metadata{})
        # Pass to parent new function with metadata
        attrs_with_metadata = Map.put(attrs, :metadata, metadata)
        GraphOS.Entity.Graph.new(attrs_with_metadata)
      end
    end
  end

  defmodule Behaviour do
    @moduledoc """
    Behaviour for Graph lifecycle hooks.
    """

    @callback on_start(options :: Keyword.t()) :: {:ok, state :: map()} | {:error, reason :: term()}
    @callback on_stop(state :: map()) :: {:ok, state :: map()} | {:error, reason :: term()}
  end
end
