defmodule GraphOS.MCP.Service.EventManager do
  @moduledoc """
  Manages event subscriptions for MCP clients.

  This module replaces the :pg based process group with a standard Registry.
  It provides functionality for:

  1. Registering clients
  2. Broadcasting events to all clients
  3. Cleaning up subscriptions
  """

  use GenServer
  require Logger

  @registry_name :mcp_clients_registry
  @topic "mcp:events"

  # Client API

  @doc """
  Starts the event manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Register the current process as a client.
  """
  def register_client do
    Registry.register(@registry_name, @topic, :client)
    :ok
  end

  @doc """
  Unregister the current process.
  """
  def unregister_client do
    Registry.unregister(@registry_name, @topic)
    :ok
  end

  @doc """
  Broadcast an event to all registered clients.
  """
  def broadcast_event(event, data) do
    Registry.dispatch(@registry_name, @topic, fn entries ->
      for {pid, _} <- entries do
        # Send message directly to the process
        send(pid, {:event, event, data})
      end
    end)
    :ok
  end

  @doc """
  Get count of connected clients.
  """
  def client_count do
    Registry.lookup(@registry_name, @topic) |> length()
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Nothing special needed for initialization
    Logger.debug("Event manager initialized")
    {:ok, %{}}
  end
end
