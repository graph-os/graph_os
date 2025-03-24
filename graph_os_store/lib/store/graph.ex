defmodule GraphOS.Store.Graph do
  @moduledoc """
  A named scope for nodes and edges.

  A Graph is a logical grouping of nodes and edges, while still allowing
  for cross-graph queries and operations.
  """

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id(),
          name: String.t(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    metadata: %{}
  ]

  @doc """
  Creates a new Graph struct.

  ## Parameters

  - `attrs` - Attributes for the graph

  ## Examples

      iex> GraphOS.Store.Graph.new(%{name: "My Graph"})
      %GraphOS.Store.Graph{id: "graph_uuid", name: "My Graph", metadata: %{}}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    id = Map.get(attrs, :id) || UUID.uuid4()
    name = Map.get(attrs, :name, "Unnamed Graph")
    metadata = Map.get(attrs, :metadata, %{})

    %__MODULE__{
      id: id,
      name: name,
      metadata: metadata
    }
  end

  @doc """
  Creates a schema for validating Graph attributes.

  ## Examples

      iex> GraphOS.Store.Graph.schema()
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
    GraphOS.Store.Schema.define(:graph, [
      %{name: :id, type: :string, required: true},
      %{name: :name, type: :string, default: "Unnamed Graph"},
      %{name: :metadata, type: :map, default: %{}}
    ])
  end
end
