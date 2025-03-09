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

  # Pipeline for MCP routes - no CSRF protection needed
  pipeline :mcp do
    plug :accepts, ["json", "sse"]
    plug Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason
  end

  scope "/", GraphOS.DevWeb do
    pipe_through :browser

    # Main dashboard routes
    get "/", DashboardController, :index
    get "/mcp", DashboardController, :mcp

    # MCP info page for visualization of dev and prod MCP servers
    get "/mcp/servers", MCPController, :info

    # CodeGraph visualization routes
    live "/code-graph", CodeGraphLive.Index, :index
    live "/code-graph/file", CodeGraphLive.File, :index
    live "/code-graph/module", CodeGraphLive.Module, :index
  end

  # MCP protocol routes - these are forwarded to the MCP endpoint
  scope "/mcp", GraphOS.DevWeb do
    pipe_through :mcp

    # Health check - quick and simple endpoint
    get "/health", MCPController, :health

    # Forward all MCP-related routes to the MCP controller
    # which will then delegate to the actual MCP endpoint
    match :*, "/*path", MCPController, :forward
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
