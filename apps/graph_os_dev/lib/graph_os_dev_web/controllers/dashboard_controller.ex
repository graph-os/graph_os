defmodule GraphOS.DevWeb.DashboardController do
  @moduledoc """
  Controller for development dashboard features.

  This controller provides a development dashboard UI for monitoring and
  debugging the GraphOS umbrella project components.
  """
  use GraphOS.DevWeb, :controller

  @doc """
  Main dashboard page showing the status of all components
  """
  def index(conn, _params) do
    # Get list of all umbrella apps
    umbrella_apps = list_umbrella_apps()

    # Get MCP status
    mcp_status = get_mcp_status()

    # Render the dashboard
    render(conn, :index,
      umbrella_apps: umbrella_apps,
      mcp_status: mcp_status
    )
  end

  @doc """
  MCP dashboard page for MCP-specific monitoring
  """
  def mcp(conn, _params) do
    # Get MCP information
    mcp_status = get_mcp_status()

    # Render the MCP dashboard
    render(conn, :mcp, mcp_status: mcp_status)
  end

  @doc """
  JSON endpoint for component status
  """
  def status(conn, _params) do
    umbrella_apps = list_umbrella_apps()
    mcp_status = get_mcp_status()

    json(conn, %{
      umbrella_apps: umbrella_apps,
      mcp: mcp_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Private helper functions

  defp list_umbrella_apps do
    # Get all applications
    Application.loaded_applications()
    |> Enum.filter(fn {app, _desc, _vsn} ->
      app_name = Atom.to_string(app)
      String.starts_with?(app_name, "graph_os_")
    end)
    |> Enum.map(fn {app, desc, vsn} ->
      %{
        name: app,
        description: desc,
        version: vsn,
        running: Application.started_applications() |> Enum.any?(fn {a, _, _} -> a == app end)
      }
    end)
  end

  defp get_mcp_status do
    mcp_running = Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :graph_os_mcp end)

    %{
      running: mcp_running,
      auto_start_http: Application.get_env(:graph_os_mcp, :auto_start_http, true),
      http_port: Application.get_env(:graph_os_mcp, :http_port, 4000),
      http_base_path: Application.get_env(:graph_os_mcp, :http_base_path, "/mcp"),
      dev_mode: Application.get_env(:graph_os_mcp, :dev_mode, false),
      endpoint_url: "http://localhost:4001/mcp"
    }
  end
end
