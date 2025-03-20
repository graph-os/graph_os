defmodule GraphOS.Server do
  use GenServer

  # State for the single instance server
  # Manages the Graph state and connections registry
  defstruct [
    :graph,
    :connections,
    :registry,
    :supervisor
  ]

  # Start the server as a supervised process
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Initialize the server with the Graph
  def init(opts) do
    {:ok, registry} = Registry.start_link(keys: :unique, name: GraphOS.ConnectionRegistry)
    {:ok, supervisor} = GraphOS.ConnSupervisor.start_link()

    # Register this server in the GraphOS registry
    {:ok, _} =
      GraphOS.Registry.register(self(), :server, %{
        name: __MODULE__,
        started_at: DateTime.utc_now()
      })

    {:ok,
     %__MODULE__{
       graph: GraphOS.GraphContextContext,
       connections: %{},
       registry: registry,
       supervisor: supervisor
     }}
  end

  # Handle connection requests
  # Returns connection process info
  def handle_call({:connect, client_info}, _from, state) do
    case GraphOS.ConnSupervisor.start_child(state.supervisor, client_info) do
      {:ok, conn_pid} ->
        # Monitor the connection process
        Process.monitor(conn_pid)

        # Register the connection in GraphOS.Registry
        {:ok, _} = GraphOS.Registry.register(conn_pid, :connection, client_info)

        # Store connection info
        new_connections = Map.put(state.connections, conn_pid, client_info)
        {:reply, {:ok, conn_pid}, %{state | connections: new_connections}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Handle connection termination
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Remove the terminated connection from our tracking
    new_connections = Map.delete(state.connections, pid)

    # Unregister from GraphOS.Registry
    GraphOS.Registry.unregister(pid)

    {:noreply, %{state | connections: new_connections}}
  end

  # API functions

  # Connect to the server (returns a connection process)
  def connect(client_info \\ %{}) do
    GenServer.call(__MODULE__, {:connect, client_info})
  end

  # Get the singleton server instance
  def instance do
    GenServer.whereis(__MODULE__)
  end

  # Get all active connections
  def connections do
    GenServer.call(__MODULE__, :connections)
  end

  # Handle request for connections list
  def handle_call(:connections, _from, state) do
    {:reply, {:ok, state.connections}, state}
  end

  # Get all active connections from the registry
  def all_connections do
    GraphOS.Registry.by_type(:connection)
  end
end
