defmodule GraphOS.MCP.Service.SessionStore do
  @moduledoc """
  Session store for MCP.

  This module provides an Agent-based session store for managing MCP sessions
  and their associated state.
  """

  use Agent
  require Logger

  @session_timeout 3_600_000 # 1 hour in milliseconds

  @doc """
  Start the session store.

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.start_link()
      {:ok, #PID<0.123.0>}
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, name: name)
  end

  @doc """
  Create a new session.

  ## Parameters

    * `session_id` - The session identifier
    * `data` - Initial session data

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.create_session("session123", %{capabilities: %{}})
      :ok
  """
  def create_session(session_id, data \\ %{}, store \\ __MODULE__) do
    session = Map.merge(%{
      id: session_id,
      created_at: DateTime.utc_now(),
      last_access: DateTime.utc_now()
    }, data)

    Agent.update(store, fn sessions ->
      Map.put(sessions, session_id, session)
    end)
  end

  @doc """
  Get a session by ID.

  ## Parameters

    * `session_id` - The session identifier

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.get_session("session123")
      {:ok, %{id: "session123", created_at: ~U[2023-01-01 00:00:00Z], ...}}

      iex> GraphOS.MCP.Service.SessionStore.get_session("nonexistent")
      {:error, :session_not_found}
  """
  def get_session(session_id, store \\ __MODULE__) do
    Agent.get_and_update(store, fn sessions ->
      case Map.get(sessions, session_id) do
        nil ->
          {{:error, :session_not_found}, sessions}

        session ->
          # Update last access time
          updated_session = %{session | last_access: DateTime.utc_now()}
          updated_sessions = Map.put(sessions, session_id, updated_session)
          {{:ok, updated_session}, updated_sessions}
      end
    end)
  end

  @doc """
  Update a session.

  ## Parameters

    * `session_id` - The session identifier
    * `data` - New session data (will be merged with existing data)

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.update_session("session123", %{user_id: "user1"})
      {:ok, %{id: "session123", user_id: "user1", ...}}

      iex> GraphOS.MCP.Service.SessionStore.update_session("nonexistent", %{})
      {:error, :session_not_found}
  """
  def update_session(session_id, data, store \\ __MODULE__) do
    Agent.get_and_update(store, fn sessions ->
      case Map.get(sessions, session_id) do
        nil ->
          {{:error, :session_not_found}, sessions}

        session ->
          # Merge new data and update last access time
          updated_session = session
                            |> Map.merge(data)
                            |> Map.put(:last_access, DateTime.utc_now())

          updated_sessions = Map.put(sessions, session_id, updated_session)
          {{:ok, updated_session}, updated_sessions}
      end
    end)
  end

  @doc """
  Delete a session.

  ## Parameters

    * `session_id` - The session identifier

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.delete_session("session123")
      :ok
  """
  def delete_session(session_id, store \\ __MODULE__) do
    Agent.update(store, fn sessions ->
      Map.delete(sessions, session_id)
    end)
  end

  @doc """
  List all sessions.

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.list_sessions()
      [%{id: "session123", ...}, %{id: "session456", ...}]
  """
  def list_sessions(store \\ __MODULE__) do
    Agent.get(store, fn sessions ->
      Map.values(sessions)
    end)
  end

  @doc """
  Clean expired sessions.

  ## Parameters

    * `timeout` - Session timeout in milliseconds (default: 1 hour)

  ## Examples

      iex> GraphOS.MCP.Service.SessionStore.clean_expired_sessions()
      {3, [:session1, :session2, :session3]}
  """
  def clean_expired_sessions(timeout \\ @session_timeout, store \\ __MODULE__) do
    now = DateTime.utc_now()

    Agent.get_and_update(store, fn sessions ->
      {expired, valid} = Enum.split_with(sessions, fn {_id, session} ->
        diff = DateTime.diff(now, session.last_access, :millisecond)
        diff > timeout
      end)

      expired_ids = Enum.map(expired, fn {id, _} -> id end)
      result = {length(expired_ids), expired_ids}

      valid_sessions = Map.new(valid)
      {result, valid_sessions}
    end)
  end
end
