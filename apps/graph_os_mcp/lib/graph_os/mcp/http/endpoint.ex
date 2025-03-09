defmodule GraphOS.MCP.HTTP.Endpoint do
  @moduledoc """
  HTTP endpoint for MCP.

  This module provides HTTP endpoints for the MCP protocol:
  - SSE endpoint for server-sent events
  - JSON-RPC endpoint for sending commands
  """

  use Plug.Router

  require Logger
  alias GraphOS.MCP.Service.Server, as: MCPServer

  @sse_keepalive_timeout 30_000 # 30 seconds

  plug Plug.Logger, log: :info

  # Add the base path from configuration if needed
  plug :match_with_base_path

  # Important: match and match routes before processing the body
  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :extract_session_id
  plug :dispatch

  # SSE Endpoint - Establish a connection and receive events
  get "/sse" do
    session_id = get_session_id(conn)

    # Register this process with the EventManager for broadcasts
    GraphOS.MCP.Service.EventManager.register_client()

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(200)
    |> send_event("connected", %{session: session_id})
    |> send_event("endpoint", "/message")
    |> sse_loop(session_id)
  end

  # Message Endpoint - Processes MCP protocol messages
  post "/message" do
    session_id = get_session_id(conn)

    case conn.body_params do
      %{"jsonrpc" => "2.0", "method" => method, "id" => id} = request ->
        params = Map.get(request, "params", %{})

        response = handle_jsonrpc_request(method, params, session_id)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{
          jsonrpc: "2.0",
          id: id,
          result: response
        }))

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{
          jsonrpc: "2.0",
          error: %{
            code: -32600,
            message: "Invalid Request"
          }
        }))
    end
  end

  # Health check endpoint
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}))
  end

  # Development mode endpoints
  if Mix.env() == :dev or Application.compile_env(:graph_os_mcp, :dev_mode, false) do
    # Note: Graph visualization endpoints have been moved to graph_os_dev app
    # Simple redirects to the new locations
    get "/graph" do
      conn
      |> put_resp_header("location", "/code-graph")
      |> send_resp(301, "")
    end

    get "/graph/file" do
      conn
      |> put_resp_header("location", "/code-graph/file")
      |> send_resp(301, "")
    end

    get "/graph/module" do
      conn
      |> put_resp_header("location", "/code-graph/module")
      |> send_resp(301, "")
    end

    # Dev UI has been moved
    get "/dev" do
      conn
      |> put_resp_header("location", "/dev")
      |> send_resp(301, "")
    end

    # Root development endpoint - redirect to dev app
    get "/" do
      conn
      |> put_resp_header("location", "/dev")
      |> send_resp(302, "")
    end
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end

  # Private functions

  # Match with the configured base path
  defp match_with_base_path(conn, _opts) do
    base_path = Application.get_env(:graph_os_mcp, :http_base_path, "/mcp")

    # If we have a base path, prepend it to all route patterns
    if base_path != "/" do
      prefix_match(conn, base_path)
    else
      conn
    end
  end

  # Handle base path prefix matching
  defp prefix_match(%{path_info: path_info} = conn, prefix) do
    prefix_parts = String.split(prefix, "/", trim: true)

    if starts_with?(path_info, prefix_parts) do
      # Remove prefix from path_info
      %{conn | path_info: Enum.drop(path_info, length(prefix_parts))}
    else
      conn
    end
  end

  defp starts_with?(_, []), do: true
  defp starts_with?([], _), do: false
  defp starts_with?([h | t1], [h | t2]), do: starts_with?(t1, t2)
  defp starts_with?(_, _), do: false

  # Extract and store session ID from query parameters or headers
  defp extract_session_id(conn, _opts) do
    session_id = get_session_id(conn) || generate_session_id()
    Plug.Conn.assign(conn, :session_id, session_id)
  end

  defp get_session_id(conn) do
    # Try to get session ID from query parameters
    case conn.query_params["sessionId"] do
      nil ->
        # If not in query params, try the header
        Plug.Conn.get_req_header(conn, "x-mcp-session") |> List.first()
      session_id ->
        session_id
    end
  end

  defp generate_session_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  # Handle JSON-RPC method calls
  defp handle_jsonrpc_request("initialize", params, session_id) do
    _protocol_version = Map.get(params, "protocolVersion")
    capabilities = Map.get(params, "capabilities", %{})

    case MCPServer.initialize(session_id, capabilities) do
      {:ok, response} -> response
      {:error, reason} -> %{error: reason}
    end
  end

  defp handle_jsonrpc_request("listTools", _params, session_id) do
    case MCPServer.list_tools(session_id) do
      {:ok, tools} -> %{tools: tools}
      {:error, reason} -> %{error: reason}
    end
  end

  defp handle_jsonrpc_request("executeTool", params, session_id) do
    tool_name = Map.get(params, "name")
    tool_params = Map.get(params, "parameters", %{})

    case MCPServer.execute_tool(session_id, tool_name, tool_params) do
      {:ok, result} -> %{result: result}
      {:error, reason} -> %{error: reason}
    end
  end

  defp handle_jsonrpc_request("ping", _params, _session_id) do
    %{ping: "pong", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
  end

  defp handle_jsonrpc_request(method, _params, _session_id) do
    %{error: "Method not found: #{method}"}
  end

  # SSE event helpers

  defp send_event(conn, event, data) when is_map(data) do
    send_event(conn, event, Jason.encode!(data))
  end

  defp send_event(conn, event, data) when is_binary(data) do
    chunk = "event: #{event}\ndata: #{data}\n\n"
    case Plug.Conn.chunk(conn, chunk) do
      {:ok, conn} -> conn
      {:error, _} -> halt(conn)
    end
  end

  # Main SSE loop with Bandit-friendly timeout handling
  defp sse_loop(conn, session_id) do
    # Set up a timer for keepalive pings
    timer_ref = Process.send_after(self(), :sse_ping, @sse_keepalive_timeout)

    receive do
      :sse_ping ->
        # Send a keepalive ping and continue the loop
        conn
        |> send_event("ping", %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
        |> sse_loop(session_id)

      {:event, event, data} ->
        # Receive event from EventManager and send it to the client
        Process.cancel_timer(timer_ref)
        conn
        |> send_event(event, data)
        |> sse_loop(session_id)

      {:send_event, event, data} ->
        # Send a custom event and continue the loop (legacy format)
        Process.cancel_timer(timer_ref)
        conn
        |> send_event(event, data)
        |> sse_loop(session_id)
    after
      # Bandit might close the connection due to read timeout, handle that gracefully
      @sse_keepalive_timeout * 2 ->
        # Clean up when the connection is closed
        GraphOS.MCP.Service.EventManager.unregister_client()
        Logger.info("SSE connection closed due to timeout: #{session_id}")
        conn
    end
  rescue
    e ->
      # Make sure to clean up even if there's an error
      GraphOS.MCP.Service.EventManager.unregister_client()
      Logger.error("Error in SSE loop: #{inspect(e)}")
      conn
  end
end
