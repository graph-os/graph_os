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
    require Logger
    
    # Check if the event type is one we're interested in
    event_type_match? = event.type in subscription.filters.events
    Logger.debug("Event type #{inspect(event.type)} in subscription events #{inspect(subscription.filters.events)}? #{event_type_match?}")
    
    # Match topic - exact match, tuple pattern match, or wildcard
    topic_match? = topic_matches?(subscription.topic, event.topic)
    Logger.debug("Subscription topic #{inspect(subscription.topic)} matches event topic #{inspect(event.topic)}? #{topic_match?}")
    
    # Check any additional filtering criteria
    filter_match? = filter_matches?(subscription.filters.filter, event)
    Logger.debug("Filter match? #{filter_match?}")
    
    result = event_type_match? and topic_match? and filter_match?
    Logger.debug("Final match result: #{result}")
    
    result
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
  
  # Topic pattern matching - define all possible combinations
  # Simple topic matching - exact match
  defp topic_matches?(subscription_topic, event_topic) when subscription_topic == event_topic do
    require Logger
    Logger.debug("Topic exact match: #{inspect(subscription_topic)} == #{inspect(event_topic)}")
    true
  end
  
  # General subscription to specific event
  defp topic_matches?(:node, {:node, _id}) do
    require Logger
    Logger.debug("Topic match: :node subscription matches specific node event")
    true
  end
  
  defp topic_matches?(:node, {:node, _id, _metadata}) do
    require Logger
    Logger.debug("Topic match: :node subscription matches specific node event with metadata")
    true
  end
  
  defp topic_matches?(:edge, {:edge, _id}) do
    require Logger
    Logger.debug("Topic match: :edge subscription matches specific edge event")
    true
  end
  
  defp topic_matches?(:edge, {:edge, _id, _metadata}) do
    require Logger
    Logger.debug("Topic match: :edge subscription matches specific edge event with metadata")
    true
  end
  
  # Entity type subscriptions
  defp topic_matches?({:node, entity_type}, {:node, _id, %{type: type}}) when entity_type == type do
    require Logger
    Logger.debug("Topic match: {:node, #{inspect(entity_type)}} matches {:node, _, %{type: #{inspect(type)}}}")
    true
  end
  
  defp topic_matches?({:node, entity_type}, {:node, _id}) do
    require Logger
    Logger.debug("Topic potential match: {:node, #{inspect(entity_type)}} with {:node, _id} - need to check entity data")
    # This is a partial match - we'll check entity data in filter_matches?
    true
  end
  
  defp topic_matches?({:edge, edge_type}, {:edge, _id, %{type: type}}) when edge_type == type do
    require Logger
    Logger.debug("Topic match: {:edge, #{inspect(edge_type)}} matches {:edge, _, %{type: #{inspect(type)}}}")
    true
  end
  
  defp topic_matches?({:edge, edge_type}, {:edge, _id}) do
    require Logger
    Logger.debug("Topic potential match: {:edge, #{inspect(edge_type)}} with {:edge, _id} - need to check entity data")
    # This is a partial match - we'll check entity data in filter_matches?
    true
  end
  
  # Default case - no match
  defp topic_matches?(subscription_topic, event_topic) do
    require Logger
    Logger.debug("Topic mismatch: subscription topic #{inspect(subscription_topic)} doesn't match event topic #{inspect(event_topic)}")
    false
  end
  
  defp filter_matches?(%{} = filter, event) do
    require Logger
    
    # Extract the data from the event - for node/edge entities, type is often in data
    event_data = event.data || %{}
    
    # Check each filter condition
    result = Enum.all?(filter, fn {key, value} ->
      case key do
        :entity_type -> 
          match = event.entity_type == value
          Logger.debug("Filter match for entity_type: #{match} (#{inspect(event.entity_type)} == #{inspect(value)})")
          match
        :entity_id -> 
          match = event.entity_id == value
          Logger.debug("Filter match for entity_id: #{match} (#{inspect(event.entity_id)} == #{inspect(value)})")
          match
        :type -> 
          # Check in both metadata and data for type
          data_type = Map.get(event_data, :type) || Map.get(event_data, "type")
          metadata_type = event.metadata && Map.get(event.metadata, :type) || Map.get(event.metadata || %{}, "type")
          match = data_type == value || metadata_type == value
          Logger.debug("Filter match for type: #{match} (data_type: #{inspect(data_type)}, metadata_type: #{inspect(metadata_type)}, value: #{inspect(value)})")
          match
        _ -> 
          # Check in metadata first, then data for any other key
          metadata_value = event.metadata && Map.get(event.metadata, key)
          data_value = Map.get(event_data, key)
          match = metadata_value == value || data_value == value
          Logger.debug("Filter match for #{inspect(key)}: #{match} (metadata: #{inspect(metadata_value)}, data: #{inspect(data_value)}, value: #{inspect(value)})")
          match
      end
    end)
    
    Logger.debug("Overall filter match result: #{result}")
    result
  end
  defp filter_matches?(_, _), do: true  # No filter means automatic match
end
