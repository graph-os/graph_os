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

    # Render the dashboard
    render(conn, :index, umbrella_apps: umbrella_apps)
  end

  @doc """
  JSON endpoint for component status
  """
  def status(conn, _params) do
    umbrella_apps = list_umbrella_apps()

    json(conn, %{
      umbrella_apps: umbrella_apps,
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
end
