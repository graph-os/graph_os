defmodule GraphOS.Store.Application do
  @moduledoc """
  Application module for GraphOS.Store.

  Starts the necessary processes for the Store to function.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GraphOS.Store.Registry
    ]

    opts = [strategy: :one_for_one, name: GraphOS.Store.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
