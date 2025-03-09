defmodule GraphOS.MCP.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Only start the HTTP server if enabled and auto_start_http is true
    http_enabled? = Application.get_env(:graph_os_mcp, :http_enabled, true)
    auto_start_http? = Application.get_env(:graph_os_mcp, :auto_start_http, true)

    children = [
      # MCP protocol service
      {GraphOS.MCP.Service.Supervisor, []}
    ]

    # Add Bandit HTTP server if enabled and auto_start_http is true
    children = if http_enabled? && auto_start_http? do
      Logger.info("Starting MCP with HTTP server")
      children ++ [bandit_child_spec()]
    else
      if !auto_start_http? do
        Logger.info("MCP HTTP server auto-start disabled, will use Phoenix forwarding")
      else
        Logger.info("MCP HTTP server disabled")
      end
      children
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GraphOS.MCP.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp bandit_child_spec do
    # Get configuration for the HTTP server
    port = Application.get_env(:graph_os_mcp, :http_port, 4000)
    host = Application.get_env(:graph_os_mcp, :http_host, {0, 0, 0, 0})
    base_path = Application.get_env(:graph_os_mcp, :http_base_path, "/mcp")

    # Log the server configuration
    Logger.info("Starting MCP HTTP server at http://#{format_host(host)}:#{port}#{base_path}")

    # Configure the Bandit server for SSE connections
    {Bandit,
      plug: {GraphOS.MCP.HTTP.Endpoint, []},
      scheme: :http,
      port: port,
      ip: host,
      thousand_island_options: [
        transport_options: [
          active: false,
          keepalive: true,
          send_timeout: 30_000,
          send_timeout_close: true
        ],
        read_timeout: 120_000  # 2 minutes
      ],
      startup_log: :info  # Use startup_log instead of plugins for logging
    }
  end

  defp format_host({0, 0, 0, 0}), do: "0.0.0.0"
  defp format_host({127, 0, 0, 1}), do: "127.0.0.1"
  defp format_host({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_host(host) when is_binary(host), do: host
end
