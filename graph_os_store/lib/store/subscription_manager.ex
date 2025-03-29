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
    # Log the event being published
    Logger.debug("Publishing event: #{inspect(event.type)} for topic #{inspect(event.topic)}")
    
    # Find all matching subscriptions
    all_subscriptions = :ets.tab2list(state.table)
    Logger.debug("Found #{length(all_subscriptions)} total subscriptions")
    
    matching_subscriptions = all_subscriptions
    |> Enum.filter(fn {_id, subscription} -> 
      match_result = Subscription.matches?(subscription, event)
      Logger.debug("Subscription #{subscription.id} for topic #{inspect(subscription.topic)} matches event? #{match_result}")
      match_result
    end)
    |> Enum.map(fn {_id, subscription} -> subscription end)
    
    Logger.debug("Found #{length(matching_subscriptions)} matching subscriptions for event")
    
    # Calculate max concurrency based on number of subscriptions
    # This prevents spawning too many tasks for small numbers of subscribers
    # but allows for maximum parallelism with larger sets
    max_concurrency = max(4, min(System.schedulers_online() * 2, length(matching_subscriptions)))
    
    # Deliver events in parallel using Task.async_stream with ordered: false for better performance
    Task.async_stream(
      matching_subscriptions,
      fn subscription -> deliver_event(event, subscription) end,
      max_concurrency: max_concurrency,
      ordered: false,
      timeout: 5000 # 5 second timeout for event delivery
    )
    |> Stream.run() # Run the stream to execute all tasks
    
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
    Logger.debug("Creating via_tuple for subscription manager with store: #{inspect(store_name)}")
    {:via, Registry, {GraphOS.Store.Registry, {__MODULE__, store_name}}}
  end
  
  defp deliver_event(event, %Subscription{} = subscription) do
    require Logger
    
    Logger.debug("Delivering event #{inspect(event.type)} for subscription #{subscription.id}")
    
    case subscription.subscriber do
      pid when is_pid(pid) ->
        Logger.debug("Delivering to process subscriber #{inspect(pid)}")
        
        # Use the original subscription topic when sending the message to the subscriber
        # This ensures backward compatibility with tests and existing clients
        send(pid, {:graph_os_store, subscription.topic, event})
        
      {module, function, args} when is_atom(module) and is_atom(function) and is_list(args) ->
        Logger.debug("Delivering to MFA subscriber #{inspect(module)}.#{inspect(function)}")
        apply(module, function, [event | args])
        
      {:via, module, name} = via_tuple when is_atom(module) ->
        Logger.debug("Delivering to via subscriber #{inspect(via_tuple)}")
        case Registry.lookup(module, name) do
          [{pid, _}] -> send(pid, {:graph_os_store, subscription.topic, event})
          _ -> Logger.warning("Via tuple subscription target not found: #{inspect(via_tuple)}")
        end
        
      name when is_atom(name) ->
        if Process.whereis(name) do
          Logger.debug("Delivering to named process #{inspect(name)}")
          send(Process.whereis(name), {:graph_os_store, subscription.topic, event})
        else
          Logger.warning("Named subscription target not found: #{inspect(name)}")
        end
        
      other ->
        Logger.error("Unknown subscriber type: #{inspect(other)}")
    end
  end
end
