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

  ## gRPC Support

  This router also supports gRPC connections via HTTP/2 when used with Bandit.
  The gRPC handler will process incoming gRPC requests and map them to appropriate
  GraphOS operations.
  """

  use Plug.Router
  require Logger

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

  # gRPC endpoint - used by the HTTP/2 handler
  post "/grpc/:service/:method" do
    handle_grpc_request(conn, service, method)
  end

  # Special handler for gRPC health checks
  get "/grpc/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "UP"}))
  end

  # Catch-all route
  match _ do
    # Log for debugging
    Logger.debug("Unmatched route: #{conn.method} #{conn.request_path}")

    # Check if this might be a gRPC request
    case get_req_header(conn, "content-type") do
      ["application/grpc" <> _] ->
        Logger.info("Detected gRPC request to #{conn.request_path}")
        # Process as generic gRPC
        path_parts = String.split(conn.request_path, "/", trim: true)

        case path_parts do
          [service, method | _] ->
            handle_grpc_request(conn, service, method)

          _ ->
            send_resp(conn, 404, "Invalid gRPC path")
        end

      _ ->
        send_resp(conn, 404, "Not found")
    end
  end

  # Handle gRPC requests
  defp handle_grpc_request(conn, service, method) do
    Logger.info("Handling gRPC request: #{service}/#{method}")

    # Get the gRPC server process
    case Process.whereis(GraphOS.Protocol.GRPCServer) do
      nil ->
        Logger.error("gRPC server not found")
        send_resp(conn, 503, "gRPC server unavailable")

      _pid ->
        cond do
          # Handle system info requests
          service == "SystemInfoService" && method == "GetSystemInfo" ->
            # Generate mock system info
            system_info = generate_system_info()

            # Serialize system info (simplified for now)
            response_data = Jason.encode!(system_info) |> :erlang.term_to_binary()

            conn
            |> put_resp_header("content-type", "application/grpc+proto")
            # 0 = OK
            |> put_resp_header("grpc-status", "0")
            |> send_resp(200, response_data)

          # Handle system info history requests
          service == "SystemInfoService" && method == "ListSystemInfo" ->
            # Generate mock system info list
            system_info_list = %{
              items: [
                generate_system_info(),
                generate_system_info(%{
                  id: "history-1",
                  timestamp: System.system_time(:second) - 3600
                }),
                generate_system_info(%{
                  id: "history-2",
                  timestamp: System.system_time(:second) - 7200
                })
              ]
            }

            # Serialize system info list (simplified for now)
            response_data = Jason.encode!(system_info_list) |> :erlang.term_to_binary()

            conn
            |> put_resp_header("content-type", "application/grpc+proto")
            # 0 = OK
            |> put_resp_header("grpc-status", "0")
            |> send_resp(200, response_data)

          # Default handler for other gRPC requests
          true ->
            # For now, respond with success to prove connection works
            conn
            |> put_resp_header("content-type", "application/grpc+proto")
            # 0 = OK
            |> put_resp_header("grpc-status", "0")
            |> send_resp(200, "")
        end
    end
  end

  # Generate mock system info
  defp generate_system_info(overrides \\ %{}) do
    # Basic system info with reasonable defaults
    base_info = %{
      id: "sys-#{System.system_time(:millisecond)}",
      hostname: "graph-os-server",
      timestamp: System.system_time(:second),
      cpu_count: System.schedulers_online(),
      cpu_load_1m: 0.25,
      cpu_load_5m: 0.15,
      cpu_load_15m: 0.10,
      # 8GB
      memory_total: 8_589_934_592,
      # 2GB
      memory_used: 2_147_483_648,
      # 6GB
      memory_free: 6_442_450_944,
      # 1 day
      uptime: System.system_time(:second) - System.system_time(:second) + 86400,
      os_version: System.version(),
      platform: :os.type() |> elem(0) |> to_string(),
      architecture: :erlang.system_info(:system_architecture) |> to_string()
    }

    # Apply any overrides
    Map.merge(base_info, overrides)
  end
end
