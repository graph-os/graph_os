defmodule SSE.ConnectionRegistry do
  @moduledoc """
  Registry for SSE connections.

  This module provides a registry for managing SSE connections and their associated
  state data. It allows looking up connections by session ID.
  """

  use GenServer

  @registry_name __MODULE__

  # Client API

  @doc """
  Starts the connection registry.
  """
  def start_link(_) do
    # Use start_link/3 with :ignore_already_started option
    GenServer.start_link(__MODULE__, :ok, name: {:global, @registry_name})
  end

  @doc """
  Gets the registry process, starting it if needed.
  """
  def get_registry do
    case :global.whereis_name(@registry_name) do
      :undefined ->
        {:error, :not_started}
      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Registers a connection with the given session ID.

  ## Parameters

  * `session_id` - The session ID for the connection
  * `conn_pid` - The PID of the connection process
  * `data` - Additional data to associate with the connection
  """
  def register(session_id, conn_pid, data \\ %{}) do
    SSE.log(:debug, "Registering connection",
      session_id: session_id,
      pid: inspect(conn_pid)
    )
    with {:ok, pid} <- get_registry() do
      GenServer.call(pid, {:register, session_id, conn_pid, data})
    end
  end

  @doc """
  Unregisters a connection with the given session ID.

  ## Parameters

  * `session_id` - The session ID for the connection
  """
  def unregister(session_id) do
    SSE.log(:debug, "Unregistering connection", session_id: session_id)
    with {:ok, pid} <- get_registry() do
      GenServer.call(pid, {:unregister, session_id})
    end
  end

  @doc """
  Looks up a connection by session ID.

  ## Parameters

  * `session_id` - The session ID to look up

  ## Returns

  * `{:ok, {pid, data}}` - If the connection is found
  * `{:error, :not_found}` - If the connection is not found
  """
  def lookup(session_id) do
    with {:ok, pid} <- get_registry() do
      GenServer.call(pid, {:lookup, session_id})
    end
  end

  @doc """
  Updates the data for a connection.

  ## Parameters

  * `session_id` - The session ID for the connection
  * `data` - The new data for the connection
  """
  def update_data(session_id, data) do
    SSE.log(:debug, "Updating connection data",
      session_id: session_id,
      data: inspect(data, pretty: true)
    )
    with {:ok, pid} <- get_registry() do
      GenServer.call(pid, {:update_data, session_id, data})
    end
  end

  @doc """
  Returns a list of all registered connections.

  ## Returns

  * `[{session_id, {pid, data}}]` - List of all registered connections
  """
  def list_connections do
    with {:ok, pid} <- get_registry() do
      GenServer.call(pid, :list_connections)
    end
  end

  @doc """
  Returns a map of all active sessions.

  ## Returns

  * `%{session_id => {pid, data}}` - Map of all sessions
  """
  def list_sessions do
    # Get the state directly from the registry
    case get_registry() do
      {:ok, pid} ->
        GenServer.call(pid, :list_sessions)

      _ ->
        %{} # Return empty map if registry not available
    end
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, session_id, conn_pid, data}, _from, state) do
    Process.monitor(conn_pid)
    new_state = Map.put(state, session_id, {conn_pid, data})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister, session_id}, _from, state) do
    new_state = Map.delete(state, session_id)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:lookup, session_id}, _from, state) do
    case Map.fetch(state, session_id) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_data, session_id, data}, _from, state) do
    case Map.fetch(state, session_id) do
      {:ok, {pid, _old_data}} ->
        new_state = Map.put(state, session_id, {pid, data})
        {:reply, :ok, new_state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_connections, _from, state) do
    connections = Enum.map(state, fn {session_id, {pid, data}} ->
      {session_id, pid, data}
    end)
    {:reply, connections, state}
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find the session ID for this PID and remove it
    session_id = Enum.find_value(state, fn {sid, {conn_pid, _data}} ->
      if conn_pid == pid, do: sid, else: nil
    end)

    if session_id do
      SSE.log(:debug, "Connection process down, unregistering", session_id: session_id)
      new_state = Map.delete(state, session_id)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
