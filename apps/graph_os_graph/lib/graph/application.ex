defmodule GraphOS.Graph.Application do
  @moduledoc """
  The GraphOS Graph Application.

  This module is responsible for starting the Graph component of the GraphOS
  umbrella application and supervising its processes.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add supervised children here as needed
    ]

    opts = [strategy: :one_for_one, name: GraphOS.Graph.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
