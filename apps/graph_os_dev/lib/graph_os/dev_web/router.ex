defmodule GraphOS.DevWeb.Router do
  use GraphOS.DevWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GraphOS.DevWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Forward all MCP-related requests to the MCP router
  # This integrates MCP functionality on the same Phoenix port
  forward "/mcp", MCP.Router

  scope "/", GraphOS.DevWeb do
    pipe_through :browser

    # Main dashboard routes
    get "/", DashboardController, :index

    # CodeGraph visualization routes
    live "/code-graph", CodeGraphLive.Index, :index
    live "/code-graph/file", CodeGraphLive.File, :index
    live "/code-graph/module", CodeGraphLive.Module, :index
  end

  scope "/", GraphOS.DevWeb do
    pipe_through :api
  end

  # API endpoints for dashboard data
  scope "/api", GraphOS.DevWeb do
    pipe_through :api

    get "/status", DashboardController, :status

    # CodeGraph API endpoints
    # Note: Consider moving these to LiveView hooks in a future update
    get "/code-graph/file", CodeGraphController, :file_data
    get "/code-graph/module", CodeGraphController, :module_data
    get "/code-graph/list", CodeGraphController, :list_data
  end

  # Enable LiveDashboard
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through :browser

    # Serve the Phoenix LiveDashboard at /dashboard
    live_dashboard "/dashboard", metrics: GraphOS.DevWeb.Telemetry
  end
end
