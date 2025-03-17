defmodule GraphOS.Graph.Edge do
  @moduledoc """
  A module for managing edges in a graph.
  """
  
  use Boundary, deps: []

  alias GraphOS.Graph.Meta

  @typedoc "The id of the edge"
  @type id() :: String.t() | integer()

  @typedoc "Optional key for the edge"
  @type key() :: String.t() | atom()

  @typedoc "Optional data of the edge"
  @type data() :: map()

  @typedoc "The weight of the edge"
  @type weight() :: integer()

  @typedoc "The edge"
  @type t() :: %__MODULE__{
    id: id(),
    key: key(),
    weight: integer(),
    source: id(),
    target: id(),
    meta: Meta.t()
  }

  @type opts() :: Keyword.t()

  @keys [:id, :key, :source, :target, :weight, :meta]
  @spec keys() :: [atom()]
  def keys, do: @keys

  defguard is_edge_key(key) when key in @keys

  defguard is_id(id) when is_binary(id) or is_integer(id)

  @derive {Jason.Encoder, only: @keys}
  @enforce_keys @keys
  defstruct @keys

  @spec new(id(), id(), opts()) :: t()
  def new(source, target, opts \\ [])
  def new(source, target, opts) when is_id(source) and is_id(target) and is_list(opts) do
    %__MODULE__{
      id: Keyword.get(opts, :id, nil),
      key: Keyword.get(opts, :key, nil),
      weight: Keyword.get(opts, :weight, 0),
      source: source,
      target: target,
      meta: Meta.new()
    }
  end
end
