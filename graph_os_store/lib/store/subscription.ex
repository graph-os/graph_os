defmodule GraphOS.Store.Subscription do
  @moduledoc """
  Subscription system for GraphOS.Store.
  
  Enables real-time notifications for store changes, allowing clients 
  to subscribe to specific events and receive notifications when they occur.
  """
  
  @type id :: binary()
  @type topic :: binary() | atom() | tuple()
  @type event_type :: :create | :update | :delete | :custom
  @type entity_type :: :node | :edge | :any
  
  @type t :: %__MODULE__{
    id: id(),
    subscriber: pid() | binary(),
    topic: topic(),
    filters: map(),
    created_at: integer()
  }
  
  @event_types [:create, :update, :delete, :custom]
  @entity_types [:node, :edge, :transaction, :any]
  
  defstruct [
    :id,
    :subscriber,
    :topic,
    :filters,
    :created_at
  ]
  
  @doc """
  Creates a new subscription.
  
  ## Options
  
  * `:events` - List of event types to subscribe to. Defaults to all events.
  * `:filter` - Map of filters to apply to events. Defaults to no filtering.
  """
  @spec new(subscriber :: pid() | binary(), topic :: topic(), opts :: keyword()) :: t()
  def new(subscriber, topic, opts \\ []) do
    events = Keyword.get(opts, :events, @event_types)
    filter = Keyword.get(opts, :filter, %{})
    
    %__MODULE__{
      id: generate_id(),
      subscriber: subscriber,
      topic: topic,
      filters: %{events: events, filter: filter},
      created_at: System.system_time(:millisecond)
    }
  end
  
  @doc """
  Validates that a subscription's topic and filter structure is valid.
  
  Returns {:ok, subscription} if valid, {:error, reason} otherwise.
  """
  @spec validate(subscription :: t()) :: {:ok, t()} | {:error, term()}
  def validate(%__MODULE__{} = subscription) do
    with {:ok, _} <- validate_topic(subscription.topic),
         {:ok, _} <- validate_filters(subscription.filters) do
      {:ok, subscription}
    end
  end
  
  @doc """
  Checks if an event matches a subscription's filters.
  
  Returns true if the event should be sent to the subscriber, false otherwise.
  """
  @spec matches?(subscription :: t(), event :: GraphOS.Store.Event.t()) :: boolean()
  def matches?(%__MODULE__{} = subscription, %GraphOS.Store.Event{} = event) do
    # Check if the event type is one we're interested in
    event_type_match? = event.type in subscription.filters.events
    
    # Match topic - exact match, tuple pattern match, or wildcard
    topic_match? = topic_matches?(subscription.topic, event.topic)
    
    # Check any additional filtering criteria
    filter_match? = filter_matches?(subscription.filters.filter, event)
    
    event_type_match? and topic_match? and filter_match?
  end
  
  # Private helper functions
  
  defp generate_id, do: UUIDv7.generate()
  
  defp validate_topic(topic) when is_binary(topic), do: {:ok, topic}
  defp validate_topic(topic) when is_atom(topic), do: {:ok, topic}
  defp validate_topic({entity_type, _}) when entity_type in @entity_types, do: {:ok, entity_type}
  defp validate_topic({entity_type, _, _}) when entity_type in @entity_types, do: {:ok, entity_type}
  defp validate_topic(topic), do: {:error, {:invalid_topic, topic}}
  
  defp validate_filters(%{events: events} = filters) do
    if Enum.all?(events, &(&1 in @event_types)) do
      {:ok, filters}
    else
      {:error, {:invalid_event_types, events}}
    end
  end
  defp validate_filters(filters), do: {:ok, filters}
  
  defp topic_matches?(topic, topic), do: true  # Exact match
  defp topic_matches?(:any, _), do: true  # Wildcard
  defp topic_matches?(:node, :node), do: true
  defp topic_matches?(:edge, :edge), do: true
  
  # Match entity type + ID pattern
  defp topic_matches?({entity_type, _}, {entity_type, _, _}), do: true
  defp topic_matches?({entity_type, id}, {entity_type, id, _}), do: true
  defp topic_matches?({entity_type, type, _}, {entity_type, type, _}), do: true
  
  # No match
  defp topic_matches?(_, _), do: false
  
  defp filter_matches?(%{} = filter, event) do
    Enum.all?(filter, fn {key, value} ->
      case key do
        :entity_type -> event.entity_type == value
        :entity_id -> event.entity_id == value
        # Add other filter criteria as needed
        _ -> Map.get(event.metadata || %{}, key) == value
      end
    end)
  end
  defp filter_matches?(_, _), do: true  # No filter means automatic match
end
