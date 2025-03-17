defmodule GraphOS.Adapter.GenServer do
  @moduledoc """
  A Graph adapter for direct Elixir integration via GenServer.

  This adapter provides a direct interface to the GraphOS Graph for Elixir
  applications. It translates GenServer calls into Graph operations and vice versa.

  ## Configuration

  - `:name` - Name to register the adapter process (optional)
  - `:plugs` - List of plugs to apply to operations (optional)
  - `:graph_module` - The Graph module to use (default: `GraphOS.Graph`)
  - `:subscription_buffer_size` - Maximum size of the subscription buffer (default: 100)

  ## Usage

  ```elixir
  # Start the adapter
  {:ok, pid} = GraphOS.Adapter.GraphAdapter.start_link(
    adapter: GraphOS.Adapter.GenServer,
    name: MyGraphAdapter,
    plugs: [
      {AuthPlug, realm: "internal"},
      LoggingPlug
    ]
  )

  # Execute a query
  {:ok, result} = GraphOS.Adapter.GraphAdapter.execute(
    MyGraphAdapter,
    {:query, "nodes.list", %{type: "person"}}
  )

  # Execute an action
  {:ok, result} = GraphOS.Adapter.GraphAdapter.execute(
    MyGraphAdapter,
    {:action, "nodes.create", %{data: %{name: "John"}}}
  )

  # Subscribe to graph events
  GraphOS.Adapter.GenServer.subscribe(MyGraphAdapter, "nodes.changed")

  # Later, you can receive events in your process like this:
  # 
  # ```elixir
  # receive do
  #   {:graph_event, "nodes.changed", event_data} ->
  #     IO.puts("Node changed: " <> inspect(event_data))
  # end
  # ```
  ```
  """

  use GraphOS.Adapter.GraphAdapter
  require Logger

  alias GraphOS.Adapter.Context
  alias GraphOS.Graph.{Transaction, Operation}

  # State for this adapter
  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            graph_module: module(),
            subscriptions: %{binary() => list({pid(), reference()})},
            subscription_monitors: %{reference() => {pid(), binary()}}
          }

    defstruct [
      :graph_module,
      subscriptions: %{},
      subscription_monitors: %{}
    ]
  end

  # Client API

  @doc """
  Subscribes to graph events of a specific type.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `event_type` - The type of events to subscribe to (e.g., "nodes.changed")
    
  ## Returns

    * `:ok` - Successfully subscribed
    * `{:error, reason}` - Failed to subscribe
  """
  @spec subscribe(module() | pid(), binary()) :: :ok | {:error, term()}
  def subscribe(adapter, event_type) when is_binary(event_type) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter

    if adapter_pid && Process.alive?(adapter_pid) do
      # Send subscription request to the adapter
      GenServer.call(adapter_pid, {:subscribe, self(), event_type})
    else
      {:error, :adapter_not_found}
    end
  end

  @doc """
  Starts the GenServer adapter as a linked process.

  ## Parameters

    * `opts` - Adapter configuration options
    
  ## Returns

    * `{:ok, pid}` - Successfully started the adapter
    * `{:error, reason}` - Failed to start the adapter
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    GraphOS.Adapter.GraphAdapter.start_link(Keyword.put(opts, :adapter, __MODULE__))
  end

  @doc """
  Unsubscribes from graph events of a specific type.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `event_type` - The type of events to unsubscribe from
    
  ## Returns

    * `:ok` - Successfully unsubscribed
    * `{:error, reason}` - Failed to unsubscribe
  """
  @spec unsubscribe(module() | pid(), binary()) :: :ok | {:error, term()}
  def unsubscribe(adapter, event_type) when is_binary(event_type) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter

    if adapter_pid && Process.alive?(adapter_pid) do
      # Send unsubscription request to the adapter
      GenServer.call(adapter_pid, {:unsubscribe, self(), event_type})
    else
      {:error, :adapter_not_found}
    end
  end

  @doc """
  Publishes an event to subscribers.

  ## Parameters

    * `adapter` - The adapter module or pid
    * `event_type` - The type of event to publish
    * `event_data` - The event data
    
  ## Returns

    * `:ok` - Event published successfully
    * `{:error, reason}` - Failed to publish event
  """
  @spec publish(module() | pid(), binary(), term()) :: :ok | {:error, term()}
  def publish(adapter, event_type, event_data) do
    # If adapter is a module, convert to pid
    adapter_pid = if is_atom(adapter), do: Process.whereis(adapter), else: adapter

    if adapter_pid && Process.alive?(adapter_pid) do
      # Send publication request to the adapter
      GenServer.cast(adapter_pid, {:publish, event_type, event_data})
    else
      {:error, :adapter_not_found}
    end
  end

  @doc """
  Executes an operation through the adapter.

  ## Parameters

    * `adapter` - The adapter pid or name
    * `operation` - The operation to execute ({:query, path, params} or {:action, path, params})
    * `context` - Optional context for the operation
    
  ## Returns

    * `{:ok, result}` - Operation completed successfully
    * `{:error, reason}` - Operation failed
  """
  @spec execute(
          module() | pid(),
          GraphOS.Adapter.GraphAdapter.operation(),
          GraphOS.Adapter.Context.t() | nil
        ) ::
          {:ok, term()} | {:error, term()}
  def execute(adapter, operation, context \\ nil) do
    GraphOS.Adapter.GraphAdapter.execute(adapter, operation, context)
  end

  # Adapter callbacks

  @impl true
  def init(opts) do
    graph_module = Keyword.get(opts, :graph_module, GraphOS.Graph)

    # Initialize the graph if needed
    case graph_module.init() do
      :ok ->
        state = %State{
          graph_module: graph_module
        }

        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_operation({:query, path, params}, context, state) do
    try do
      # Process the query based on the path
      result =
        case path do
          "nodes.get" ->
            with {:ok, node_id} <- extract_param(params, "id") do
              # Use the graph module to get a node by ID
              state.graph_module.query(start_node_id: node_id)
            end

          "nodes.list" ->
            # Extract filter parameters
            filters = Map.get(params, "filters", %{})

            # Use the graph module to query nodes
            state.graph_module.query(filters)

          "edges.get" ->
            with {:ok, edge_id} <- extract_param(params, "id") do
              # Get edge by ID
              state.graph_module.query(edge_id: edge_id)
            end

          "search" ->
            with {:ok, query_string} <- extract_param(params, "query") do
              # Perform a search query
              state.graph_module.query(
                search: query_string,
                filters: Map.get(params, "filters", %{})
              )
            end

          "path.shortest" ->
            with {:ok, source_id} <- extract_param(params, "source"),
                 {:ok, target_id} <- extract_param(params, "target") do
              # Find shortest path
              state.graph_module.shortest_path(source_id, target_id)
            end

          "components.connected" ->
            # Find connected components
            state.graph_module.connected_components()

          "algorithm.pagerank" ->
            # Calculate PageRank
            state.graph_module.pagerank()

          _ ->
            {:error, {:unknown_path, path}}
        end

      case result do
        {:ok, data} ->
          # Query succeeded
          updated_context = Context.put_result(context, data)
          {:reply, data, updated_context, state}

        {:error, reason} ->
          # Query failed
          updated_context =
            Context.put_error(context, :query_error, "Query error: #{inspect(reason)}")

          {:error, reason, updated_context, state}
      end
    rescue
      e ->
        # Handle unexpected errors
        Logger.error("Error in GenServer adapter query: #{inspect(e)}")

        updated_context =
          Context.put_error(context, :internal_error, "Internal error: #{inspect(e)}")

        {:error, {:internal_error, e}, updated_context, state}
    end
  end

  @impl true
  def handle_operation({:action, path, params}, context, state) do
    try do
      # Process the action based on the path
      result =
        case path do
          "nodes.create" ->
            with {:ok, data} <- extract_param(params, "data") do
              # Create a new node
              transaction =
                build_transaction(state, [
                  Operation.new(:create, :node, data, [])
                ])

              state.graph_module.execute(transaction)
            end

          "nodes.update" ->
            with {:ok, id} <- extract_param(params, "id"),
                 {:ok, data} <- extract_param(params, "data") do
              # Update a node
              transaction =
                build_transaction(state, [
                  Operation.new(:update, :node, data, id: id)
                ])

              state.graph_module.execute(transaction)
            end

          "nodes.delete" ->
            with {:ok, id} <- extract_param(params, "id") do
              # Delete a node
              transaction =
                build_transaction(state, [
                  Operation.new(:delete, :node, %{}, id: id)
                ])

              state.graph_module.execute(transaction)
            end

          "edges.create" ->
            with {:ok, source} <- extract_param(params, "source"),
                 {:ok, target} <- extract_param(params, "target"),
                 {:ok, type} <- extract_param(params, "type") do
              # Create a new edge
              transaction =
                build_transaction(state, [
                  Operation.new(:create, :edge, %{}, source: source, target: target, type: type)
                ])

              state.graph_module.execute(transaction)
            end

          "edges.update" ->
            with {:ok, id} <- extract_param(params, "id"),
                 {:ok, data} <- extract_param(params, "data") do
              # Update an edge
              transaction =
                build_transaction(state, [
                  Operation.new(:update, :edge, data, id: id)
                ])

              state.graph_module.execute(transaction)
            end

          "edges.delete" ->
            with {:ok, id} <- extract_param(params, "id") do
              # Delete an edge
              transaction =
                build_transaction(state, [
                  Operation.new(:delete, :edge, %{}, id: id)
                ])

              state.graph_module.execute(transaction)
            end

          "execute.node" ->
            with {:ok, id} <- extract_param(params, "id"),
                 {:ok, execution_context} <- extract_param(params, "context") do
              # Execute a node
              state.graph_module.execute_node_by_id(id, execution_context)
            end

          _ ->
            {:error, {:unknown_path, path}}
        end

      case result do
        {:ok, data} ->
          # Action succeeded
          updated_context = Context.put_result(context, data)

          # Publish an event for this action
          event_type = "#{path}.completed"

          :ok =
            publish_event(state, event_type, %{
              path: path,
              params: params,
              result: data
            })

          {:reply, data, updated_context, state}

        {:error, reason} ->
          # Action failed
          updated_context =
            Context.put_error(context, :action_error, "Action error: #{inspect(reason)}")

          {:error, reason, updated_context, state}
      end
    rescue
      e ->
        # Handle unexpected errors
        Logger.error("Error in GenServer adapter action: #{inspect(e)}")

        updated_context =
          Context.put_error(context, :internal_error, "Internal error: #{inspect(e)}")

        {:error, {:internal_error, e}, updated_context, state}
    end
  end

  # Additional GenServer callbacks for subscriptions

  @doc false
  def handle_call({:subscribe, pid, event_type}, _from, %State{} = state) do
    # Monitor the subscriber process
    monitor_ref = Process.monitor(pid)

    # Add to subscriptions
    subscriptions =
      Map.update(
        state.subscriptions,
        event_type,
        [{pid, monitor_ref}],
        fn subscribers -> [{pid, monitor_ref} | subscribers] end
      )

    # Keep track of the monitor reference
    subscription_monitors =
      Map.put(
        state.subscription_monitors,
        monitor_ref,
        {pid, event_type}
      )

    updated_state = %{
      state
      | subscriptions: subscriptions,
        subscription_monitors: subscription_monitors
    }

    {:reply, :ok, updated_state}
  end

  @doc false
  def handle_call({:unsubscribe, pid, event_type}, _from, %State{} = state) do
    # Find and remove the subscription
    case Map.get(state.subscriptions, event_type, []) do
      [] ->
        # No subscriptions for this event type
        {:reply, :ok, state}

      subscribers ->
        # Remove this subscriber
        {matching, remaining} =
          Enum.split_with(subscribers, fn {sub_pid, _} -> sub_pid == pid end)

        # Update subscriptions
        subscriptions =
          if remaining == [] do
            Map.delete(state.subscriptions, event_type)
          else
            Map.put(state.subscriptions, event_type, remaining)
          end

        # Remove monitors
        subscription_monitors =
          Enum.reduce(matching, state.subscription_monitors, fn {_, ref}, acc ->
            # Demonitor the process
            Process.demonitor(ref, [:flush])
            Map.delete(acc, ref)
          end)

        updated_state = %{
          state
          | subscriptions: subscriptions,
            subscription_monitors: subscription_monitors
        }

        {:reply, :ok, updated_state}
    end
  end

  @doc false
  def handle_cast({:publish, event_type, event_data}, %State{} = state) do
    # Get subscribers for this event type
    subscribers = Map.get(state.subscriptions, event_type, [])

    # Send event to all subscribers
    Enum.each(subscribers, fn {pid, _} ->
      send(pid, {:graph_event, event_type, event_data})
    end)

    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, ref, :process, pid, _reason}, %State{} = state) do
    # Process a subscriber process going down
    case Map.get(state.subscription_monitors, ref) do
      nil ->
        # Unknown monitor reference
        {:noreply, state}

      {^pid, event_type} ->
        # Remove the subscription
        subscription_monitors = Map.delete(state.subscription_monitors, ref)

        subscriptions =
          Map.update(
            state.subscriptions,
            event_type,
            [],
            fn subscribers ->
              Enum.reject(subscribers, fn {sub_pid, sub_ref} ->
                sub_pid == pid and sub_ref == ref
              end)
            end
          )

        # Remove empty subscription lists
        subscriptions =
          if subscriptions[event_type] == [] do
            Map.delete(subscriptions, event_type)
          else
            subscriptions
          end

        updated_state = %{
          state
          | subscriptions: subscriptions,
            subscription_monitors: subscription_monitors
        }

        {:noreply, updated_state}
    end
  end

  # Private helper functions

  # Extract a parameter from the params map
  defp extract_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_param, key}}
    end
  end

  # Build a transaction from operations
  defp build_transaction(state, operations) do
    # Get the store module from the graph module
    store_module = apply(Module.concat([state.graph_module, "Store"]), :get_store_module, [])

    # The id is no longer part of the Transaction struct
    %Transaction{
      store: store_module,
      operations: operations
    }
  end

  # Publish an event to subscribers
  defp publish_event(state, event_type, event_data) do
    subscribers = Map.get(state.subscriptions, event_type, [])

    # Only publish if there are subscribers
    if subscribers != [] do
      Enum.each(subscribers, fn {pid, _} ->
        send(pid, {:graph_event, event_type, event_data})
      end)
    end

    :ok
  end
end
