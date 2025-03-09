defmodule GraphOS.DevWeb.MCPController do
  @moduledoc """
  Controller for forwarding MCP protocol requests to the MCP endpoint.

  This controller acts as a bridge between the Phoenix web interface
  and the existing MCP HTTP endpoint implementation, allowing us to:

  1. Use existing MCP functionality without reimplementing it
  2. Keep the MCP implementation in its dedicated app
  3. Add development-specific features in the dev app
  """
  use GraphOS.DevWeb, :controller
  alias GraphOS.MCP.HTTP.Endpoint, as: MCPEndpoint
  require Logger

  @doc """
  Forward requests to the MCP endpoint for handling.
  This is the main entry point that handles all MCP-related requests.
  """
  def forward(conn, _params) do
    # Get the original request path without the mcp prefix
    path = get_mcp_path(conn)

    # Call the MCP endpoint's call function directly (it's a Plug)
    # We need to recreate a conn with the proper path
    conn = %{conn | path_info: path_to_segments(path), request_path: path}

    # Handle the request with the MCP endpoint
    MCPEndpoint.call(conn, [])
  end

  @doc """
  Health check endpoint for the MCP service
  """
  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      component: "mcp",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Display information about MCP servers (both Dev and Prod)
  """
  def info(conn, _params) do
    # Get information about both MCP servers
    mcp_servers = [
      get_dev_mcp_info(),
      get_prod_mcp_info()
    ]

    render(conn, :info, mcp_servers: mcp_servers)
  end

  # Helper function to get the MCP path
  defp get_mcp_path(conn) do
    # Extract the path after /mcp
    path_parts = conn.path_info

    case path_parts do
      ["mcp" | rest] ->
        "/" <> Enum.join(rest, "/")
      _ ->
        "/"
    end
  end

  # Convert path string to path segments
  defp path_to_segments(""), do: []
  defp path_to_segments("/"), do: []
  defp path_to_segments(path) do
    path
    |> String.trim_leading("/")
    |> String.split("/")
  end

  # Get information about the development MCP server (Phoenix-integrated)
  defp get_dev_mcp_info do
    %{
      name: "Development MCP (Phoenix-integrated)",
      description: "Stable MCP server integrated with the Phoenix dev server",
      running: Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :graph_os_dev end),
      endpoint_url: "http://localhost:4001/mcp",
      http_port: 4001,
      http_base_path: "/mcp",
      auto_start_http: false,
      dev_mode: true,
      is_development: true
    }
  end

  # Get information about the production MCP server (standalone)
  defp get_prod_mcp_info do
    mcp_running = Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :graph_os_mcp end)
    auto_start_http = Application.get_env(:graph_os_mcp, :auto_start_http, false)
    http_port = Application.get_env(:graph_os_mcp, :http_port, 4000)

    %{
      name: "Production MCP (Standalone)",
      description: "Full-featured MCP server for application use",
      running: mcp_running,
      endpoint_url: "http://localhost:#{http_port}/mcp",
      http_port: http_port,
      http_base_path: Application.get_env(:graph_os_mcp, :http_base_path, "/mcp"),
      auto_start_http: auto_start_http,
      dev_mode: Application.get_env(:graph_os_mcp, :dev_mode, false),
      is_development: false
    }
  end
end
