defmodule GraphOS.Store.Event do
  @moduledoc """
  Represents an event in the GraphOS.Store system.
  
  Events are used to notify subscribers about changes to the store,
  such as entity creation, updates, or deletions.
  """
  
  @type id :: binary()
  @type event_type :: :create | :update | :delete | :custom
  @type entity_type :: :node | :edge | :transaction | :any
  @type entity_id :: binary() | nil
  
  @type t :: %__MODULE__{
    id: id(),
    type: event_type(),
    topic: term(),
    entity_type: entity_type(),
    entity_id: entity_id(),
    data: map() | nil,
    metadata: map() | nil,
    timestamp: integer()
  }
  
  defstruct [
    :id,
    :type,
    :topic,
    :entity_type,
    :entity_id,
    :data,
    :metadata,
    :timestamp
  ]
  
  @doc """
  Creates a new event.
  
  ## Parameters
  
  * `type` - The type of event (:create, :update, :delete, or :custom)
  * `topic` - The topic of the event (used for routing to subscribers)
  * `entity_type` - The type of entity this event relates to
  * `entity_id` - The ID of the entity this event relates to
  * `data` - Optional data payload for the event
  * `metadata` - Optional metadata for the event
  """
  @spec new(type :: event_type(), topic :: term(), entity_type :: entity_type(), entity_id :: entity_id(), opts :: keyword()) :: t()
  def new(type, topic, entity_type, entity_id, opts \\ []) do
    data = Keyword.get(opts, :data)
    metadata = Keyword.get(opts, :metadata, %{})
    
    %__MODULE__{
      id: generate_id(),
      type: type,
      topic: topic,
      entity_type: entity_type,
      entity_id: entity_id,
      data: data,
      metadata: metadata,
      timestamp: System.system_time(:millisecond)
    }
  end
  
  @doc """
  Creates an event for an entity creation.
  """
  @spec create(entity_type :: entity_type(), entity_id :: entity_id(), data :: map(), opts :: keyword()) :: t()
  def create(entity_type, entity_id, data, opts \\ []) do
    topic = Keyword.get(opts, :topic, entity_type)
    new(:create, topic, entity_type, entity_id, [data: data] ++ opts)
  end
  
  @doc """
  Creates an event for an entity update.
  """
  @spec update(entity_type :: entity_type(), entity_id :: entity_id(), data :: map(), opts :: keyword()) :: t()
  def update(entity_type, entity_id, data, opts \\ []) do
    topic = Keyword.get(opts, :topic, entity_type)
    new(:update, topic, entity_type, entity_id, [data: data] ++ opts)
  end
  
  @doc """
  Creates an event for an entity deletion.
  """
  @spec delete(entity_type :: entity_type(), entity_id :: entity_id(), opts :: keyword()) :: t()
  def delete(entity_type, entity_id, opts \\ []) do
    topic = Keyword.get(opts, :topic, entity_type)
    new(:delete, topic, entity_type, entity_id, opts)
  end
  
  @doc """
  Creates a custom event.
  """
  @spec custom(topic :: term(), entity_type :: entity_type(), entity_id :: entity_id(), opts :: keyword()) :: t()
  def custom(topic, entity_type, entity_id, opts \\ []) do
    new(:custom, topic, entity_type, entity_id, opts)
  end
  
  # Private helper functions
  
  defp generate_id, do: UUIDv7.generate()
end
