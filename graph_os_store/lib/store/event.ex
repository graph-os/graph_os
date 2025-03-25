defmodule GraphOS.Store.Event do
  @moduledoc """
  Represents an event in the store.

  This struct is used to encapsulate information about changes to entities
  in the store, providing a consistent structure for subscribers to process.
  """

  @type event_type :: :create | :update | :delete | :custom
  @type t :: %__MODULE__{
    id: binary(),
    type: event_type(),
    topic: binary(),
    entity_type: atom(),
    entity_id: binary(),
    entity: struct() | nil,
    previous: struct() | nil,
    changes: map(),
    metadata: map(),
    timestamp: DateTime.t()
  }

  defstruct [
    :id,
    :type,
    :topic,
    :entity_type,
    :entity_id,
    :entity,
    :previous,
    :changes,
    metadata: %{},
    timestamp: nil
  ]

  @doc """
  Creates a new Event struct.

  ## Parameters

  - `attrs` - Attributes for the event
    - `:type` - The type of event (:create, :update, :delete, :custom)
    - `:topic` - The topic this event belongs to
    - `:entity_type` - The type of entity (:graph, :node, :edge)
    - `:entity_id` - The ID of the entity
    - `:entity` - The entity struct (if available)
    - `:previous` - The previous entity state (for updates)
    - `:changes` - Map of changes made (for updates)
    - `:metadata` - Additional metadata for the event

  ## Examples

      iex> GraphOS.Store.Event.new(%{type: :create, entity_type: :node, entity_id: "user123", entity: %MyApp.User{}})
      %GraphOS.Store.Event{
        id: "event_uuid",
        type: :create,
        entity_type: :node,
        entity_id: "user123",
        entity: %MyApp.User{},
        timestamp: ~U[2023-01-01 12:00:00Z]
      }
  """
  @spec new(map()) :: t()
  def new(attrs) do
    id = Map.get(attrs, :id) || UUID.uuid4()
    type = Map.get(attrs, :type)
    topic = Map.get(attrs, :topic)
    entity_type = Map.get(attrs, :entity_type)
    entity_id = Map.get(attrs, :entity_id)
    entity = Map.get(attrs, :entity)
    previous = Map.get(attrs, :previous)
    changes = Map.get(attrs, :changes, %{})
    metadata = Map.get(attrs, :metadata, %{})
    timestamp = Map.get(attrs, :timestamp) || DateTime.utc_now()

    %__MODULE__{
      id: id,
      type: type,
      topic: topic,
      entity_type: entity_type,
      entity_id: entity_id,
      entity: entity,
      previous: previous,
      changes: changes,
      metadata: metadata,
      timestamp: timestamp
    }
  end

  @doc """
  Creates a topic string for an entity.

  ## Parameters

  - `entity_type` - The type of entity (:graph, :node, :edge)
  - `entity_id` - The ID of the entity (optional)

  ## Examples

      iex> GraphOS.Store.Event.topic_for(:node, "user123")
      "node:user123"

      iex> GraphOS.Store.Event.topic_for(:node)
      "node"
  """
  @spec topic_for(atom(), binary() | nil) :: binary()
  def topic_for(entity_type, entity_id \\ nil) do
    if entity_id do
      "#{entity_type}:#{entity_id}"
    else
      "#{entity_type}"
    end
  end

  @doc """
  Creates a topic string for a pattern.

  ## Parameters

  - `pattern` - The pattern to create a topic for

  ## Examples

      iex> GraphOS.Store.Event.topic_for_pattern({MyApp.User, "user123"})
      "pattern:MyApp.User:user123"

      iex> GraphOS.Store.Event.topic_for_pattern(MyApp.User)
      "pattern:MyApp.User"

      iex> GraphOS.Store.Event.topic_for_pattern("custom:topic")
      "pattern:custom:topic"
  """
  @spec topic_for_pattern(term()) :: binary()
  def topic_for_pattern(pattern) do
    case pattern do
      {module, id} when is_atom(module) and is_binary(id) ->
        "pattern:#{module}:#{id}"
      module when is_atom(module) ->
        "pattern:#{module}"
      topic when is_binary(topic) ->
        "pattern:#{topic}"
      _ ->
        "pattern:#{inspect(pattern)}"
    end
  end
end
