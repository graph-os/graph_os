defmodule GraphOS.Protocol.Router do
  @moduledoc """
  HTTP router for GraphOS protocol integration.

  This module provides a Plug router for handling HTTP requests to GraphOS components.
  It maps HTTP routes to GraphOS operations and vice versa. This router can be used
  directly as a Plug or embedded in a Phoenix router.

  ## Usage

  ```elixir
  # In a Phoenix router
  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api" do
    pipe_through :api
    
    forward "/graph", GraphOS.Protocol.Router, [
      adapter_opts: [
        graph_module: MyApp.Graph,
        plugs: [
          {MyApp.AuthPlug, realm: "api"},
          MyApp.LoggingPlug
        ]
      ]
    ]
  end
  ```

  Or run it as a standalone HTTP server:

  ```elixir
  # Start the HTTP server
  adapter_opts = [
    graph_module: MyApp.Graph,
    plugs: [
      {MyApp.AuthPlug, realm: "api"},
      MyApp.LoggingPlug
    ]
  ]

  Plug.Cowboy.http(GraphOS.Protocol.Router, [adapter_opts: adapter_opts], port: 4000)
  ```
  """

  use Plug.Router

  # Plug middleware
  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  # Define routes

  # Query operations
  get "/query/:path" do
    send_resp(conn, 200, "Query: #{path}")
  end

  post "/query/:path" do
    send_resp(conn, 200, "Query with body: #{path}")
  end

  # Action operations
  post "/action/:path" do
    send_resp(conn, 200, "Action: #{path}")
  end

  # JSON-RPC endpoint
  get "/jsonrpc" do
    send_resp(conn, 200, "JSON-RPC discovery")
  end

  post "/jsonrpc" do
    send_resp(conn, 200, "JSON-RPC request")
  end

  # Subscriptions
  get "/subscribe" do
    send_resp(conn, 200, "Subscribe to events")
  end

  # Catch-all route
  match _ do
    send_resp(conn, 404, "Not found")
  end
end
