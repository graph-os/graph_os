defmodule GraphOS.Store.Meta do
  @moduledoc """
  A module for managing metadata for the graph.
  """

  use Boundary, deps: []

  @typedoc "The creation date of the node"
  @type created_at() :: DateTime.t()
  @typedoc "The last update date of the node"
  @type updated_at() :: DateTime.t()
  @typedoc "The deletion date of the node"
  @type deleted_at() :: DateTime.t() | nil
  @typedoc "The version of the node"
  @type version() :: non_neg_integer()
  @typedoc "Whether the node is deleted"
  @type deleted() :: boolean()

  @typedoc "The metadata for a graph, a node or an edge"
  @type t() :: %__MODULE__{
          created_at: created_at(),
          updated_at: updated_at(),
          deleted_at: deleted_at(),
          version: version(),
          deleted: deleted()
        }

  @type opt() ::
          {:created_at, created_at()}
          | {:updated_at, updated_at()}
          | {:deleted_at, deleted_at()}
          | {:version, version()}
          | {:deleted, deleted()}

  @type opts() :: [opt()]

  @keys [:created_at, :updated_at, :deleted_at, :version, :deleted]
  @derive {Jason.Encoder, only: @keys}
  defguard is_metadata_key(key) when key in @keys

  @enforce_keys @keys
  defstruct @keys

  @spec new(opts()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now()),
      updated_at: Keyword.get(opts, :updated_at, DateTime.utc_now()),
      deleted_at: Keyword.get(opts, :deleted_at, nil),
      version: Keyword.get(opts, :version, 0),
      deleted: Keyword.get(opts, :deleted, false)
    }
  end
end
