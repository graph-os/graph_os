defmodule GraphOS.ConnSupervisor do
  @moduledoc """
  Supervises connection processes.
  """

  use Supervisor

  @doc """
  Starts the connection supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new connection process.
  """
  def start_child(client_info) do
    Supervisor.start_child(__MODULE__, [client_info])
  end

  @impl true
  def init(_opts) do
    children = [
      # Define the child specification for connections
      %{
        id: GraphOS.Conn,
        start: {GraphOS.Conn, :start_link, []},
        # Don't restart failed connections
        restart: :temporary,
        # Give connections time to clean up
        shutdown: 5000
      }
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end
end
