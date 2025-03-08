defmodule GraphOS.MCP.Service.Supervisor do
  @moduledoc """
  Supervisor for GraphOS.MCP service components.

  This supervisor manages MCP protocol services, including server, tools, and handlers.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # MCP server
      {GraphOS.MCP.Service.Server, []},

      # Tools registry
      {Registry, keys: :unique, name: GraphOS.MCP.Tools.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
