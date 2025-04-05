defmodule GraphOS.Conn do
  @moduledoc """
  Handles individual connections to GraphOS.
  Manages the connection lifecycle and message handling.
  """

  use GenServer
  require Logger

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
    subscriber = self()
    # TODO: Determine the correct store_name for this connection
    store_name = :default_graph_store

    case GraphOS.Store.SubscriptionManager.subscribe(store_name, subscriber, topic, opts) do
      {:ok, subscription_id} ->
        {:reply, {:ok, subscription_id},
         %{state | subscriptions: [subscription_id | state.subscriptions]}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    # TODO: Determine the correct store_name for this connection
    store_name = :default_graph_store

    case GraphOS.Store.SubscriptionManager.unsubscribe(store_name, subscription_id) do
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
      {:error, _reason} -> {:noreply, state}
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

  # Alias core modules needed for dispatch
  # TODO: Verify these modules exist and contain the expected functions
  alias GraphOS.Core.FileSystem
  # alias GraphOS.Core.SystemCommand # Example for other modules
  alias GraphOS.Store.SubscriptionManager

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

  defp handle_initialization(_message, state) do
    # Handle initialization messages
    # This could include authentication, protocol negotiation, etc.
    {:ok, %{state | state: :connected}}
  end

  # Handles messages received when the connection state is :connected
  # Dispatches query and action operations.
  defp handle_connected_message({:query, path, params}, state) do
    # Placeholder: Get actor_id from assigns (replace with real auth later)
    actor_id = Map.get(state.assigns, :actor_id)

    result =
      if actor_id do
        # Dispatch query based on path
        case path do
          "filesystem.read" ->
            case Map.fetch(params, "path") do
              {:ok, file_path} ->
                # FileSystem.read(actor_id, file_path, params)
                {:error, {:not_implemented, "FileSystem.read"}} # Placeholder result
              :error ->
                {:error, {:missing_param, "path"}}
            end

          "filesystem.list" ->
             case Map.fetch(params, "path") do
              {:ok, dir_path} ->
                # FileSystem.list(actor_id, dir_path, params)
                {:error, {:not_implemented, "FileSystem.list"}} # Placeholder result
              :error ->
                {:error, {:missing_param, "path"}}
            end
          # Add more query paths here...
          _ ->
            {:error, {:unknown_path, path}}
        end
      else
        # Actor ID not found - handle unauthorized
        {:error, :unauthorized}
      end

    # Send result back via transport if available
    send_response({:query_result, path, result}, state)

    # Return :ok to handle_cast
    {:ok, state}
  end

  defp handle_connected_message({:action, path, params}, state) do
    # Placeholder: Get actor_id from assigns (replace with real auth later)
    actor_id = Map.get(state.assigns, :actor_id)

    result =
      if actor_id do
        # Dispatch action based on path
        case path do
          "filesystem.write" ->
            with {:ok, file_path} <- Map.fetch(params, "path"),
                 {:ok, content} <- Map.fetch(params, "content") do
              # FileSystem.write(actor_id, file_path, content, params)
              {:error, {:not_implemented, "FileSystem.write"}} # Placeholder result
            else
              :error -> {:error, {:missing_param, "path or content"}}
            end

          # Add more action paths here...
          _ ->
            {:error, {:unknown_path, path}}
        end
      else
        # Actor ID not found - handle unauthorized
        {:error, :unauthorized}
      end

    # Send result back via transport if available
    send_response({:action_result, path, result}, state)

    # Return :ok to handle_cast
    {:ok, state}
  end

  # Fallback for unknown message formats when connected
  defp handle_connected_message(unknown_message, state) do
    # Log the unknown message
    Logger.warning("Received unknown message format in GraphOS.Conn: #{inspect(unknown_message)}")
    # Send error back? Depends on protocol requirements.
    send_response({:error, :invalid_message_format}, state)
    {:ok, state} # Keep the connection alive
  end

  # Helper to send response via transport if available
  defp send_response(response_message, %{transport: transport} = state) when not is_nil(transport) do
    # TODO: Verify this is the correct way to send messages back via transport
    # The transport module might need a specific function or format.
    # Assuming transport module implements send_message/2 for now.
    case transport.send_message(response_message, state) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Failed to send response via transport: #{inspect(reason)}")
    end
  rescue
    e -> Logger.error("Error sending response via transport: #{inspect(e)}")
  end
  defp send_response(_response_message, %{transport: nil}) do
    # No transport configured for this connection
    :ok
  end
end
