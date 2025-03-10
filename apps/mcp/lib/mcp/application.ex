defmodule MCP.Application do
  @moduledoc """
  The MCP application module.

  This module is responsible for starting the MCP server and its dependencies.
  """

  use Application
  require Logger

  @doc false
  def start(_type, _args) do
    Logger.info("Starting MCP application")

    children = [
      # Start the SSE connection registry
      {Registry, keys: :unique, name: SSE.ConnectionRegistry},

      # Start Finch for HTTP requests
      {Finch, name: MCP.Finch}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MCP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
