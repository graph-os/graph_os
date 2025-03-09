defmodule GraphOS.Graph.Operation do
  @moduledoc """
  A module for managing operations on a graph.
  """

  alias GraphOS.Graph.Node
  alias GraphOS.Graph.Edge

  @typedoc "The entity to perform the operation on"
  @type entity() :: :node | :edge

  @typedoc "The id of the entity"
  @type id() :: Node.id() | Edge.id()

  @typedoc "The action to perform on the entity"
  @type action() ::
    :create
    | :update
    | :delete

  @typedoc "The options for the operation"
  @type opts() :: Node.opts() | Edge.opts()

  @typedoc "The operation"
  @type t() :: %__MODULE__{
    action: action(),
    entity: entity(),
    data: map(),
    opts: opts()
  }

  @typedoc "The operation as a tuple"
  @type message() ::
    {action(), entity(), map(), opts()}
    | {action(), entity(), map()}
    | {action(), entity(), id()}
    | {action(), entity()}

  @entities [:node, :edge, Node, Edge]
  defguard is_entity(entity) when entity in @entities

  @actions [:create, :update, :delete]
  defguard is_action(action) when action in @actions

  defguard is_id(id) when is_binary(id) or is_integer(id)

  defstruct [:action, :entity, data: %{}, opts: []]

  @spec new(action(), entity(), map(), opts()) :: t()
  def new(action, entity, data, opts) do
    %__MODULE__{
      action: action,
      entity: entity,
      data: data,
      opts: opts
    }
  end

  @spec from_message(message()) :: t()
  def from_message(message) do
    case message do
      {action, entity, data, opts} when is_action(action) and is_entity(entity) and is_map(data) and is_list(opts) ->
        %__MODULE__{
          action: action,
          entity: entity,
          data: data,
          opts: opts
        }

      {action, entity, data} when is_action(action) and is_entity(entity) and is_map(data) ->
        %__MODULE__{
          action: action,
          entity: entity,
          data: data,
          opts: []
        }

      {action, entity, id} when is_action(action) and is_entity(entity) and is_id(id) ->
        %__MODULE__{
          action: action,
          entity: entity,
          data: %{},
          opts: [id: id]
        }

      {action, entity} when is_action(action) and is_entity(entity) ->
        %__MODULE__{
          action: action,
          entity: entity,
          data: %{},
          opts: []
        }

      _ ->
        raise ArgumentError, "Invalid operation message: #{inspect(message)}"
    end
  end

  @spec to_message(t()) :: message()
  def to_message(%__MODULE__{} = operation) do
    {operation.action, operation.entity, operation.data, operation.opts}
  end
end
