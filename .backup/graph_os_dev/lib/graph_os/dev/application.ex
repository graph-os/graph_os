defmodule GraphOS.Dev.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Log that we're starting the GraphOS.Dev application with integrated MCP support
    Logger.info("Starting GraphOS.Dev with integrated MCP support")

    children = [
      GraphOS.DevWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:graph_os_dev, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GraphOS.Dev.PubSub},
      # Start a worker by calling: GraphOS.Dev.Worker.start_link(arg)
      # {GraphOS.Dev.Worker, arg},
      # CodeGraph and GitIntegration are disabled during refactoring
      # Ensure MCP application is started with basic implementation
      Supervisor.child_spec({Task, fn -> ensure_mcp_started() end}, id: :mcp_task),
      # Start to serve requests, typically the last entry
      GraphOS.DevWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GraphOS.Dev.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GraphOS.DevWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Ensure MCP application is properly started
  defp ensure_mcp_started do
    Logger.info("Ensuring MCP application is started")
    case Application.ensure_all_started(:mcp) do
      {:ok, started_apps} ->
        Logger.info("MCP started successfully, loaded applications: #{inspect(started_apps)}")
        
        # CodeGraph is disabled during refactoring, using default MCP server
        Logger.info("Using default MCP.Server implementation (CodeGraph disabled)")
        Application.put_env(:mcp, :server_module, MCP.Server)

      {:error, {app, reason}} ->
        Logger.error("Failed to start MCP. Failed application: #{app}, reason: #{inspect(reason)}")
    end
  end

  # CodeGraph service is disabled during refactoring
  # The ensure_code_graph_started function is commented out for reference
  # defp ensure_code_graph_started do
  #   if Application.get_env(:graph_os_dev, :enable_code_graph, false) do
  #     Logger.info("Ensuring CodeGraph service is started")
  #
  #     # Check if the CodeGraph service is already running
  #     case Process.whereis(GraphOS.Dev.CodeGraph.Service) do
  #       nil ->
  #         # If not running, start it with configured options
  #         code_graph_opts = [
  #           watched_dirs: Application.get_env(:graph_os_dev, :watch_directories, ["lib"]),
  #           file_pattern: Application.get_env(:graph_os_dev, :file_pattern, "**/*.ex"),
  #           exclude_pattern: Application.get_env(:graph_os_dev, :exclude_pattern),
  #           auto_reload: Application.get_env(:graph_os_dev, :auto_reload, false),
  #           poll_interval: Application.get_env(:graph_os_dev, :poll_interval, 1000),
  #           distributed: Application.get_env(:graph_os_dev, :distributed, true)
  #         ]
  #
  #         case GraphOS.Dev.CodeGraph.Service.start_link(code_graph_opts) do
  #           {:ok, _pid} ->
  #             Logger.info("Started CodeGraph service")
  #           {:error, {:already_started, _pid}} ->
  #             Logger.info("CodeGraph service already running")
  #           {:error, error} ->
  #             Logger.error("Failed to start CodeGraph service: #{inspect(error)}")
  #         end
  #
  #       _pid ->
  #         Logger.info("CodeGraph service already running")
  #     end
  #   end
  # end
end
