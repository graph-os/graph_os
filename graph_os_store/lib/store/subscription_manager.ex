defmodule GraphOS.Store.SubscriptionManager do
  @moduledoc """
  Manages subscriptions and handles event publishing for GraphOS.Store.
  
  This module is responsible for storing subscriptions, delivering events to
  subscribers, and handling subscription lifecycle management.
  """
  
  use GenServer
  require Logger
  
  alias GraphOS.Store.Subscription
  alias GraphOS.Store.Event
  
  @table_name_suffix "_subscriptions"
  
  # Client API
  
  @doc """
  Starts the subscription manager for a store.
  """
  def start_link(store_name) do
    GenServer.start_link(__MODULE__, store_name, name: via_tuple(store_name))
  end
  
  @doc """
  Creates a new subscription and registers it with the subscription manager.
  """
  @spec subscribe(store_name :: term(), subscriber :: pid() | term(), topic :: term(), opts :: keyword()) :: 
    {:ok, Subscription.id()} | {:error, term()}
  def subscribe(store_name, subscriber, topic, opts \\ []) do
    GenServer.call(via_tuple(store_name), {:subscribe, subscriber, topic, opts})
  end
  
  @doc """
  Cancels an existing subscription.
  """
  @spec unsubscribe(store_name :: term(), subscription_id :: Subscription.id()) :: :ok | {:error, term()}
  def unsubscribe(store_name, subscription_id) do
    GenServer.call(via_tuple(store_name), {:unsubscribe, subscription_id})
  end
  
  @doc """
  Lists all active subscriptions for a store.
  """
  @spec list_subscriptions(store_name :: term()) :: {:ok, [Subscription.t()]} | {:error, term()}
  def list_subscriptions(store_name) do
    GenServer.call(via_tuple(store_name), :list_subscriptions)
  end
  
  @doc """
  Lists all active subscriptions for a specific subscriber.
  """
  @spec list_subscriber_subscriptions(store_name :: term(), subscriber :: pid() | term()) :: 
    {:ok, [Subscription.t()]} | {:error, term()}
  def list_subscriber_subscriptions(store_name, subscriber) do
    GenServer.call(via_tuple(store_name), {:list_subscriber_subscriptions, subscriber})
  end
  
  @doc """
  Publishes an event to all matching subscribers.
  """
  @spec publish(store_name :: term(), event :: Event.t()) :: :ok
  def publish(store_name, %Event{} = event) do
    GenServer.cast(via_tuple(store_name), {:publish, event})
  end
  
  # Server callbacks
  
  @impl true
  def init(store_name) do
    table_name = table_name(store_name)
    
    # Create ETS table for subscriptions if it doesn't exist
    if :ets.info(table_name) == :undefined do
      :ets.new(table_name, [:named_table, :set, :protected, 
                           {:read_concurrency, true}, 
                           {:write_concurrency, true}])
    end
    
    {:ok, %{store_name: store_name, table: table_name}}
  end
  
  @impl true
  def handle_call({:subscribe, subscriber, topic, opts}, _from, state) do
    # Create and validate a new subscription
    subscription = Subscription.new(subscriber, topic, opts)
    
    case Subscription.validate(subscription) do
      {:ok, valid_subscription} ->
        # Store the subscription
        :ets.insert(state.table, {valid_subscription.id, valid_subscription})
        {:reply, {:ok, valid_subscription.id}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    # Delete the subscription from the ETS table
    case :ets.lookup(state.table, subscription_id) do
      [{^subscription_id, _subscription}] ->
        :ets.delete(state.table, subscription_id)
        {:reply, :ok, state}
        
      [] ->
        {:reply, {:error, :subscription_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:list_subscriptions, _from, state) do
    subscriptions = :ets.tab2list(state.table)
                   |> Enum.map(fn {_id, subscription} -> subscription end)
    {:reply, {:ok, subscriptions}, state}
  end
  
  @impl true
  def handle_call({:list_subscriber_subscriptions, subscriber}, _from, state) do
    subscriptions = :ets.tab2list(state.table)
                   |> Enum.filter(fn {_id, subscription} -> 
                        subscription.subscriber == subscriber
                      end)
                   |> Enum.map(fn {_id, subscription} -> subscription end)
                   
    {:reply, {:ok, subscriptions}, state}
  end
  
  @impl true
  def handle_cast({:publish, event}, state) do
    # Find all matching subscriptions and deliver the event
    :ets.tab2list(state.table)
    |> Enum.each(fn {_id, subscription} ->
      if Subscription.matches?(subscription, event) do
        deliver_event(subscription, event)
      end
    end)
    
    {:noreply, state}
  end
  
  # Private helper functions
  
  defp table_name(store_name) do
    case store_name do
      name when is_atom(name) -> 
        String.to_atom(Atom.to_string(name) <> @table_name_suffix)
      name when is_binary(name) -> 
        String.to_atom(name <> @table_name_suffix)
      _ -> 
        raise "Invalid store name format: #{inspect(store_name)}"
    end
  end
  
  defp via_tuple(store_name) do
    {:via, Registry, {GraphOS.Store.Registry, {__MODULE__, store_name}}}
  end
  
  defp deliver_event(%Subscription{subscriber: subscriber} = _subscription, event) when is_pid(subscriber) do
    # For process subscribers, send a message
    send(subscriber, {:graph_os_store, event.topic, event})
  end
  
  defp deliver_event(%Subscription{subscriber: subscriber, id: id} = _subscription, event) do
    # For named subscribers (e.g., Phoenix PubSub channels), use a callback mechanism
    # This is just a placeholder - the actual implementation would depend on your needs
    Logger.debug("Delivering event #{inspect(event.type)} to subscriber #{inspect(subscriber)} (subscription #{id})")
    # TODO: Implement proper callback mechanism for named subscribers
  end
end
