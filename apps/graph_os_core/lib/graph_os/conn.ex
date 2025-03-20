defmodule GraphOS.Conn do
  @moduledoc """
  Handles individual connections to GraphOS.
  Manages the connection lifecycle and message handling.
  """

  use GenServer

  @type t :: %__MODULE__{
          id: String.t(),
          client_info: map(),
          server: pid(),
          transport: module(),
          state: :initializing | :connected | :closing,
          last_activity: DateTime.t(),
          assigns: map(),
          subscriptions: [reference()]
        }

  defstruct [
    :id,
    :client_info,
    :server,
    :transport,
    :state,
    :last_activity,
    assigns: %{},
    subscriptions: []
  ]

  # Client API

  @doc """
  Starts a new connection process.
  """
  def start_link(client_info) do
    GenServer.start_link(__MODULE__, client_info)
  end

  @doc """
  Sends a message to the connection.
  """
  def send_message(conn_pid, message) do
    GenServer.cast(conn_pid, {:send_message, message})
  end

  @doc """
  Closes the connection.
  """
  def close(conn_pid) do
    GenServer.stop(conn_pid, :normal)
  end

  @doc """
  Assigns a value to the connection.
  """
  def assign(conn_pid, key, value) do
    GenServer.cast(conn_pid, {:assign, key, value})
  end

  @doc """
  Subscribes to graph events.
  """
  def subscribe(conn_pid, topic, opts \\ []) do
    GenServer.call(conn_pid, {:subscribe, topic, opts})
  end

  @doc """
  Unsubscribes from graph events.
  """
  def unsubscribe(conn_pid, subscription_id) do
    GenServer.call(conn_pid, {:unsubscribe, subscription_id})
  end

  # Server Callbacks

  def init(client_info) do
    # Get the server instance
    server = GraphOS.Server.instance()

    # Generate a unique connection ID
    id = generate_connection_id()

    # Initialize connection state
    state = %{
      id: id,
      client_info: client_info,
      server: server,
      # Will be set when transport is established
      transport: nil,
      state: :initializing,
      last_activity: DateTime.utc_now(),
      assigns: %{},
      subscriptions: []
    }

    {:ok, struct(__MODULE__, state)}
  end

  def handle_call({:subscribe, topic, opts}, _from, state) do
    # Add self() as subscriber if not specified
    opts = Keyword.put_new(opts, :subscriber, self())

    case GraphOS.GraphContext.Subscription.subscribe(topic, opts) do
      {:ok, subscription_id} ->
        {:reply, {:ok, subscription_id},
         %{state | subscriptions: [subscription_id | state.subscriptions]}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case GraphOS.GraphContext.Subscription.unsubscribe(subscription_id) do
      :ok ->
        {:reply, :ok, %{state | subscriptions: List.delete(state.subscriptions, subscription_id)}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_cast({:send_message, message}, state) do
    # Update last activity
    state = %{state | last_activity: DateTime.utc_now()}

    # Handle the message based on connection state
    case handle_message(message, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, reason} -> {:noreply, state}
    end
  end

  def handle_cast({:assign, key, value}, state) do
    assigns = Map.put(state.assigns, key, value)
    {:noreply, %{state | assigns: assigns}}
  end

  def handle_info(:timeout, state) do
    # Handle connection timeout
    {:stop, :timeout, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # Handle process termination
    {:stop, reason, state}
  end

  def handle_info({:graph_event, topic, event}, state) do
    # Forward graph events to the transport
    case state.transport do
      nil ->
        {:noreply, state}

      transport ->
        transport.send_message({:graph_event, topic, event}, state)
        {:noreply, state}
    end
  end

  # Private Functions

  defp generate_connection_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp handle_message(message, state) do
    case state.state do
      :initializing ->
        handle_initialization(message, state)

      :connected ->
        handle_connected_message(message, state)

      :closing ->
        {:error, :connection_closing}
    end
  end

  defp handle_initialization(message, state) do
    # Handle initialization messages
    # This could include authentication, protocol negotiation, etc.
    {:ok, %{state | state: :connected}}
  end

  defp handle_connected_message(message, state) do
    # Handle messages from connected clients
    # This is where you'll implement your message handling logic
    {:ok, state}
  end
end
