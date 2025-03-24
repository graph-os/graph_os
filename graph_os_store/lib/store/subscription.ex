defmodule GraphOS.Store.Subscription do
  @moduledoc """
  The default implementation of GraphOS.Store.SubscriptionBehaviour.

  This module provides the actual subscription functionality using GenServer
  to maintain a registry of subscribers and handle event broadcasting.
  """

  @behaviour GraphOS.Store.SubscriptionBehaviour

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Initialize with empty subscriber registry
    {:ok,
     %{
       # topic -> [pid]
       subscribers: %{},
       # subscription_id -> {topic, pid}
       subscriptions: %{}
     }}
  end

  @impl GraphOS.Store.SubscriptionBehaviour
  def initialize(_opts) do
    :ok
  end

  @impl GraphOS.Store.SubscriptionBehaviour
  def subscribe(topic, opts \\ []) do
    subscriber = Keyword.get(opts, :subscriber, self())
    GenServer.call(__MODULE__, {:subscribe, topic, subscriber})
  end

  @impl GraphOS.Store.SubscriptionBehaviour
  def unsubscribe(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @impl GraphOS.Store.SubscriptionBehaviour
  def broadcast(topic, event) do
    GenServer.cast(__MODULE__, {:broadcast, topic, event})
  end

  @impl GraphOS.Store.SubscriptionBehaviour
  def pattern_topic(pattern, _opts \\ []) do
    {:ok, "pattern:#{inspect(pattern)}"}
  end

  # GenServer callbacks

  @impl GenServer
  def handle_call({:subscribe, topic, subscriber}, _from, state) do
    subscription_id = make_ref()

    # Add to subscribers registry
    subscribers =
      Map.update(
        state.subscribers,
        topic,
        [subscriber],
        &[subscriber | &1]
      )

    # Add to subscriptions registry
    subscriptions =
      Map.put(
        state.subscriptions,
        subscription_id,
        {topic, subscriber}
      )

    {:reply, {:ok, subscription_id},
     %{state | subscribers: subscribers, subscriptions: subscriptions}}
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case Map.pop(state.subscriptions, subscription_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {{topic, subscriber}, subscriptions} ->
        # Remove from subscribers registry
        subscribers =
          Map.update!(state.subscribers, topic, fn subscribers ->
            List.delete(subscribers, subscriber)
          end)

        {:reply, :ok, %{state | subscribers: subscribers, subscriptions: subscriptions}}
    end
  end

  @impl GenServer
  def handle_cast({:broadcast, topic, event}, state) do
    case Map.get(state.subscribers, topic) do
      nil ->
        {:noreply, state}

      subscribers ->
        # Send event to all subscribers
        Enum.each(subscribers, fn subscriber ->
          send(subscriber, {:graph_event, topic, event})
        end)

        {:noreply, state}
    end
  end
end
