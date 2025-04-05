defmodule GraphOS.Action.PidStore do
  @moduledoc """
  An Agent to store the mapping between action execution IDs and runner PIDs.
  """
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Stores the PID for a given execution ID.
  """
  def put(execution_id, pid) when is_pid(pid) do
    Agent.update(__MODULE__, &Map.put(&1, execution_id, pid))
  end

  @doc """
  Retrieves the PID for a given execution ID.
  """
  def get(execution_id) do
    Agent.get(__MODULE__, &Map.get(&1, execution_id))
  end

  @doc """
  Deletes the mapping for a given execution ID.
  """
  def delete(execution_id) do
    Agent.update(__MODULE__, &Map.delete(&1, execution_id))
  end
end
