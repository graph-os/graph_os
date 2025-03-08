defmodule GraphOS.Core.Access.Supervisor do
  @moduledoc """
  Supervisor for GraphOS.Core access control components.

  This supervisor manages the access control services and permissions system.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Access control service
      {GraphOS.Core.Access.Service, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
