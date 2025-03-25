defmodule GraphOS.Entity.Metadata do
  @moduledoc """
  Metadata struct for entities.
  """

  @type t() :: %__MODULE__{
    id: GraphOS.Entity.id() | nil, # The id of the entity (if metadata is decoupled)
    entity: GraphOS.Entity.entity_type(),
    module: module(),              # The module that defines the entity
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    deleted_at: DateTime.t(),
    version: non_neg_integer(),
    deleted: boolean()
  }

  defstruct [:id, :entity, :module, :created_at, :updated_at, :deleted_at, :version, :deleted]

  @doc """
  Returns the schema for metadata structs.
  """
  @spec schema() :: map()
  def schema do
    GraphOS.Store.Schema.define(:metadata, [
      %{name: :id, type: :string},
      %{name: :entity, type: :string},
      %{name: :module, type: :atom},
      %{name: :created_at, type: :datetime},
      %{name: :updated_at, type: :datetime},
      %{name: :deleted_at, type: :datetime},
      %{name: :version, type: :integer},
      %{name: :deleted, type: :boolean},
    ])
  end

  @doc """
  Set the updated_at field to the current time.
  """
  @spec touch(t()) :: t()
  def touch(%__MODULE__{} = metadata) do
    %{metadata | updated_at: DateTime.utc_now()}
  end

  @doc """
  Set the deleted flag to true and the deleted_at field to the current time.
  """
  @spec set_deleted(t() | map()) :: t()
  def set_deleted(%__MODULE__{ deleted: false } = metadata) do
    %{metadata | deleted_at: DateTime.utc_now(), deleted: true}
  end

  @doc """
  Increment the version number.
  """
  @spec increment_version(t() | map()) :: t()
  def increment_version(%__MODULE__{} = metadata) do
    %{metadata | version: metadata.version + 1}
  end

  @doc """
  Check if the entity is deleted.
  """
  @spec deleted?(t() | map()) :: boolean()
  def deleted?(%__MODULE__{deleted: true}), do: true
  def deleted?(%__MODULE__{deleted: false}), do: false
  def deleted?(%__MODULE__{deleted: nil}), do: false
  def deleted?(%{metadata: metadata}), do: deleted?(metadata)
end
