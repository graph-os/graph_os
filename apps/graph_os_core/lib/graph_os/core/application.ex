defmodule GraphOS.Core.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Action Registry Agent (for metadata)
      {GraphOS.Action.Registry, []},
      # Start the Action PID Store Agent (for execution_id -> pid mapping)
      {GraphOS.Action.PidStore, []},
      # Start the Action Runner Supervisor
      {GraphOS.Action.Supervisor, []}
    ]

    # Add CodeGraph Service if enabled
    children =
      if Application.get_env(:graph_os_core, :enable_code_graph, false) do
        # Get configuration for code graph
        code_graph_opts = [
          watched_dirs: Application.get_env(:graph_os_core, :watch_directories, ["lib"]),
          file_pattern: Application.get_env(:graph_os_core, :file_pattern, "**/*.ex"),
          exclude_pattern: Application.get_env(:graph_os_core, :exclude_pattern),
          auto_reload: Application.get_env(:graph_os_core, :auto_reload, false),
          poll_interval: Application.get_env(:graph_os_core, :poll_interval, 1000),
          distributed: Application.get_env(:graph_os_core, :distributed, true)
        ]

        children ++ [{GraphOS.Dev.CodeGraph.Service, code_graph_opts}]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GraphOS.Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
