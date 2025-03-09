defmodule GraphOS.Graph.Node do
  @moduledoc """
  A node in a `GraphOS.Graph`.
  """
  alias GraphOS.Graph.Meta

  @typedoc "The id of the node"
  @type id() :: String.t() | integer()

  @typedoc "Optional key for the node"
  @type key() :: String.t() | atom()

  @typedoc "The data of the node"
  @type data() :: Map.t()

  @typedoc "Options for the node"
  @type opts() :: Keyword.t()

  @typedoc "The module that defines the schema of the node"
  @type schema() :: module()

  @typedoc "The node"
  @type t() :: %__MODULE__{
    id: id(),
    key: key(),
    data: data(),
    meta: Meta.t(),
    schema: schema()
  }

  @keys [:id, :key, :data, :meta, :schema]

  @spec keys() :: [atom()]
  def keys, do: @keys

  @derive {Jason.Encoder, only: @keys}
  defguard is_node_key(key) when key in @keys

  defstruct @keys

  @spec new(data(), opts()) :: t()
  def new(data \\ %{}, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, nil),
      key: Keyword.get(opts, :key, nil),
      data: data,
      meta: Meta.new(),
      schema: Keyword.get(opts, :schema, nil)
    }
  end
end
