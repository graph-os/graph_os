defmodule GraphOS.Protocol.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Define the children to be supervised
    children = [
      # No default supervised children at this time
      # Protocol adapters are typically started by the applications that use them
    ]

    # Start the supervisor with the strategy
    opts = [strategy: :one_for_one, name: GraphOS.Protocol.Supervisor]
    Supervisor.start_link(children, opts)
  end
end