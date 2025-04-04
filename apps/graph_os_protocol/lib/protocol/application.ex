defmodule GraphOS.Protocol.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting GraphOS Protocol application")

    # Configuration for Bandit/HTTP endpoint
    # Port can be configured via config files (config :bandit, port: 4001)
    # or defaults here.
    port = Application.get_env(:bandit, :port, 4000)

    # Define the children for the main supervisor
    children = [
      # SSE.ConnectionRegistry is started by the :mcp application dependency
      # {SSE.ConnectionRegistry, []},
      # Start Bandit, telling it to use our Router plug
      {Bandit, plug: GraphOS.Protocol.Router, port: port}
    ]

    # Start the supervisor with the strategy
    opts = [strategy: :one_for_one, name: GraphOS.Protocol.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
