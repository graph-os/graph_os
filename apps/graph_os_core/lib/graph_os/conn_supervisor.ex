defmodule GraphOS.ConnSupervisor do
  @moduledoc """
  Supervisor for GraphOS connection processes.

  Manages the lifecycle of individual connection processes,
  providing a way to start and monitor connections.
  """

  use DynamicSupervisor

  @doc """
  Starts the connection supervisor.
  """
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new connection process under supervision.
  """
  def start_child(supervisor, client_info) do
    # Define the child specification for a new connection
    child_spec = %{
      id: GraphOS.Conn,
      start: {GraphOS.Conn, :start_link, [client_info]},
      # Don't restart connections if they crash
      restart: :temporary,
      shutdown: 5000
    }

    # Start the child process
    DynamicSupervisor.start_child(supervisor, child_spec)
  end

  @impl true
  def init(_opts) do
    # Initialize the dynamic supervisor with default options
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 60
    )
  end
end
