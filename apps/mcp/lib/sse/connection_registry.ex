defmodule SSE.ConnectionRegistry do
  @moduledoc """
  API wrapper for the SSE Connection Registry.

  This module provides functions to interact with the Registry process
  started by the MCP application supervisor, which manages SSE connection state.
  """
  require Logger

  # This is the name given to the Registry in MCP.Application
  @registry_name SSE.ConnectionRegistry

  @doc """
  Registers a connection with the given session ID and initial data.
  The `session_id` is used as the key.
  Initial data should include `%{handler_pid: pid, plug_pid: pid}`.
  """
  def register(session_id, initial_data \\ %{}) do
    Logger.debug("Registering session in registry", [
      registry: @registry_name,
      session_id: session_id,
      data: inspect(initial_data)
    ])
    # Register using session_id as the key and the data map as the value
    # Also monitor the handler_pid from the initial_data
    handler_pid = Map.get(initial_data, :handler_pid)
    if handler_pid, do: Process.monitor(handler_pid)
    Registry.register(@registry_name, session_id, initial_data)
  end

  @doc """
  Unregisters a connection by session ID.
  """
  def unregister(session_id) do
    Logger.debug("Unregistering session", [
       registry: @registry_name,
       session_id: session_id
    ])
    Registry.unregister(@registry_name, session_id)
  end

  @doc """
  Looks up connection data by session ID.
  Returns `{:ok, data}` or `:error`. Note: Registry.lookup returns a list.
  """
  def lookup(session_id) do
     case Registry.lookup(@registry_name, session_id) do
       [{_pid, data}] -> {:ok, data} # Extract data from the first match
       [] -> {:error, :not_found}
     end
  end

  @doc """
  Updates the data for a registered session ID.
  Merges the `new_data` map with the existing data.
  Returns `:ok` or `:error`. Note: Registry.update_value returns boolean.
  """
  def update_data(session_id, new_data) do
    Logger.debug("Updating session data", [
      registry: @registry_name,
      session_id: session_id,
      new_data: inspect(new_data)
    ])
    # Use Registry.update_value/3 to update the data map associated with the session_id key
    # The function should return the new merged map.
    result = Registry.update_value(@registry_name, session_id, fn existing_data ->
      Map.merge(existing_data || %{}, new_data)
    end)

    # Convert boolean result from update_value to :ok/:error tuple for consistency
    if result, do: :ok, else: {:error, :update_failed_or_not_found}
  end

  @doc """
  Returns a list of all registered session IDs.
  """
  def list_connections() do
    Registry.keys(@registry_name, self()) # `self()` is arbitrary for keys
  end

  @doc """
  Returns a map of all active sessions (session_id => data).
  """
  def list_sessions() do
     Registry.select(@registry_name, [{{:_, :_, :_}, [], [:"$_"]}])
     |> Enum.into(%{}, fn {key, value} -> {key, value} end) # Key is session_id, value is data map
  end

  @doc """
  Finds a handler PID based on a value in its metadata (e.g., plug_pid).
  WARNING: This performs a linear scan and can be slow with many connections.
  """
  def find_by_metadata(key, value) do
    sessions = list_sessions() # Gets %{session_id => data}
    Enum.find_value(sessions, fn {_session_id, data} ->
      if Map.get(data, key) == value, do: {:ok, Map.get(data, :handler_pid)}, else: nil
    end) || {:error, :not_found}
  end

  @doc """
  Finds metadata based on a value in it (e.g., plug_pid).
  WARNING: This performs a linear scan and can be slow with many connections.
  """
  def find_metadata_by(key, value) do
     sessions = list_sessions() # Gets %{session_id => data}
     Enum.find_value(sessions, fn {_session_id, data} ->
       if Map.get(data, key) == value, do: {:ok, data}, else: nil
     end) || {:error, :not_found}
  end
end
