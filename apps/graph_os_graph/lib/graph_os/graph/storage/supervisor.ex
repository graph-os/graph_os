defmodule GraphOS.Graph.Storage.Supervisor do
  @moduledoc """
  Supervisor for GraphOS.Graph storage components.

  This supervisor manages the ETS tables and other storage-related processes.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Add ETS table manager
      {GraphOS.Graph.Storage.ETS, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
