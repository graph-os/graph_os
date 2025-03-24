defmodule GraphOS.Store.Operation do
  @moduledoc """
  Defines an operation for GraphOS.Store.

  An operation represents a change to be made to the store,
  such as inserting, updating, or deleting an entity.
  """

  @type entity_type :: :graph | :node | :edge
  @type operation_type :: :insert | :update | :delete
  @type t :: %__MODULE__{
          type: operation_type(),
          entity: entity_type(),
          params: map()
        }

  defstruct type: nil,
            entity: nil,
            params: %{}

  @doc """
  Creates a new operation.

  ## Parameters

  - `type` - The type of operation (:insert, :update, :delete)
  - `entity` - The type of entity (:graph, :node, :edge)
  - `params` - Parameters for the operation

  ## Examples

      iex> GraphOS.Store.Operation.new(:insert, :node, %{id: "node1", name: "Test Node"})
      %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node1", name: "Test Node"}}
  """
  @spec new(operation_type(), entity_type(), map()) :: t()
  def new(type, entity, params)
      when type in [:insert, :update, :delete] and entity in [:graph, :node, :edge] do
    %__MODULE__{
      type: type,
      entity: entity,
      params: params
    }
  end

  @doc """
  Creates a new operation with options.

  ## Parameters

  - `type` - The type of operation (:insert, :update, :delete)
  - `entity` - The type of entity (:graph, :node, :edge)
  - `params` - Parameters for the operation
  - `opts` - Options for the operation (will be merged into params)

  ## Examples

      iex> GraphOS.Store.Operation.new(:insert, :node, %{name: "Test Node"}, id: "node1")
      %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node1", name: "Test Node"}}
  """
  @spec new(operation_type(), entity_type(), map(), Keyword.t()) :: t()
  def new(type, entity, params, opts)
      when type in [:insert, :update, :delete] and entity in [:graph, :node, :edge] do
    merged_params =
      opts
      |> Enum.into(%{})
      |> Map.merge(params)

    %__MODULE__{
      type: type,
      entity: entity,
      params: merged_params
    }
  end

  @doc """
  Validates the operation.

  ## Examples

      iex> operation = GraphOS.Store.Operation.new(:insert, :node, %{id: "node1"})
      iex> GraphOS.Store.Operation.validate(operation)
      :ok

      iex> operation = GraphOS.Store.Operation.new(:update, :node, %{})
      iex> GraphOS.Store.Operation.validate(operation)
      {:error, :missing_id}
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{type: type, params: params}) do
    case type do
      :insert ->
        # For inserts, we allow missing ID as it will be generated
        :ok

      :update ->
        # For updates, we require ID
        if Map.has_key?(params, :id) do
          :ok
        else
          {:error, :missing_id}
        end

      :delete ->
        # For deletes, we require ID
        if Map.has_key?(params, :id) do
          :ok
        else
          {:error, :missing_id}
        end

      unknown ->
        # Unknown operation type
        {:error, {:unknown_operation, unknown}}
    end
  end

  @doc """
  Converts a message tuple to an Operation struct.

  This is used for backward compatibility with code that still uses the tuple format.

  ## Examples

      iex> GraphOS.Store.Operation.from_message({:node, :insert, %{id: "node1", name: "Test Node"}})
      %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node1", name: "Test Node"}}
  """
  @spec from_message(tuple()) :: t()
  def from_message({entity, type, params})
      when is_atom(entity) and is_atom(type) and is_map(params) do
    %__MODULE__{
      type: type,
      entity: entity,
      params: params
    }
  end

  def from_message({entity, type, params, _id_field})
      when is_atom(entity) and is_atom(type) and is_map(params) do
    # For backward compatibility, some callers may include an id_field parameter
    %__MODULE__{
      type: type,
      entity: entity,
      params: params
    }
  end
end
