defmodule GraphOS.MCP.Service.EventBroadcaster do
  @moduledoc """
  Broadcasts events to connected MCP clients.

  This module provides functionality to send events to clients connected via SSE.
  """

  require Logger
  alias GraphOS.MCP.Service.EventManager

  @doc """
  Broadcast an event to all connected clients.

  ## Parameters

  - `type` - The event type (e.g., "file_changed", "graph_updated")
  - `name` - The event name/category
  - `data` - The event data payload (will be converted to JSON)

  ## Examples

      iex> EventBroadcaster.broadcast("dev", "file_changed", %{path: "apps/graph_os_graph/lib/graph.ex"})
      :ok
  """
  @spec broadcast(String.t(), String.t(), map() | String.t()) :: :ok
  def broadcast(_type, name, data) do
    # Convert data to JSON if it's a map
    data_json = if is_map(data), do: Jason.encode!(data), else: data

    # Use EventManager to broadcast to all clients
    EventManager.broadcast_event(name, data_json)
    :ok
  rescue
    e ->
      Logger.error("Failed to broadcast event: #{inspect(e)}")
      :ok
  end

  @doc """
  Send an event to a specific client process.

  ## Parameters

  - `pid` - The process ID of the client
  - `type` - The event type
  - `name` - The event name
  - `data` - The event data payload
  """
  @spec send_event(pid(), String.t(), String.t(), map() | String.t()) :: :ok
  def send_event(pid, _type, name, data) when is_pid(pid) do
    # Convert data to JSON if it's a map
    data_json = if is_map(data), do: Jason.encode!(data), else: data

    # Send the event to the client process
    send(pid, {:event, name, data_json})
    :ok
  rescue
    e ->
      Logger.error("Failed to send event to client: #{inspect(e)}")
      :error
  end
end
