defmodule MCP.Router do
  @moduledoc """
  Router for the MCP server.

  This module defines routes for the MCP server with configurable modes:
  - :sse - Only SSE connection endpoint
  - :debug - SSE endpoint with JSON/API debugging
  - :inspect - Full HTML/JS endpoints with all of the above
  """

  use Plug.Router

  require Logger

  alias MCP.Server

  # Basic Plug setup
  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch

  # Mode configuration
  @doc """
  Creates a new router with the specified mode.

  ## Modes

  * `:sse` - Only the SSE connection endpoint
  * `:debug` - SSE endpoint with JSON/API debugging
  * `:inspect` - Full HTML/JS endpoints with all of the above
  """
  def new(mode) when mode in [:sse, :debug, :inspect] do
    %{
      mode: mode,
      module: __MODULE__
    }
  end

  # Helper to check the current mode
  defp current_mode(conn) do
    conn.private[:mcp_mode] || :sse
  end

  # SSE connection endpoint (available in all modes)
  get "/sse" do
    session_id = UUID.uuid4()
    Logger.info("New SSE connection", session_id: session_id)

    # Start the MCP server for this session
    Server.start(session_id)

    # Return the session ID and message endpoint in the initial SSE event
    initial_data = %{
      session_id: session_id,
      message_endpoint: "/rpc/#{session_id}"
    }

    # Handle the SSE connection
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(200)
    |> send_sse_data(session_id, initial_data)
  end

  # Root path returns mode information - useful for checking server status
  get "/" do
    mode = current_mode(conn)
    response = %{
      status: "ok",
      mode: mode,
      server: "GraphOS MCP Server",
      version: "0.1.0"
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  # The following routes are only available in :debug and :inspect modes

  # JSON-RPC request endpoint (without session ID)
  post "/rpc" do
    if should_handle_route?(conn, [:debug, :inspect]) do
      conn = fetch_query_params(conn)
      session_id = conn.query_params["session_id"]

      if session_id do
        handle_rpc_request(conn, session_id)
      else
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing session_id parameter"}))
      end
    else
      not_found(conn)
    end
  end

  # JSON-RPC request endpoint (with session ID in path)
  post "/rpc/:session_id" do
    if should_handle_route?(conn, [:debug, :inspect]) do
      handle_rpc_request(conn, session_id)
    else
      not_found(conn)
    end
  end

  # Debug information for a specific session
  get "/debug/:session_id" do
    if should_handle_route?(conn, [:debug, :inspect]) do
      case SSE.ConnectionRegistry.lookup(session_id) do
        {:ok, {_pid, data}} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{
            session_id: session_id,
            session_data: redact_sensitive_data(data)
          }))

        {:error, :not_found} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, Jason.encode!(%{error: "Session not found"}))
      end
    else
      not_found(conn)
    end
  end

  # List active sessions
  get "/debug/sessions" do
    if should_handle_route?(conn, [:debug, :inspect]) do
      # Get sessions from registry using the list_sessions function
      session_map = SSE.ConnectionRegistry.list_sessions()
      sessions = Map.keys(session_map)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{sessions: sessions}))
    else
      not_found(conn)
    end
  end

  # JSON API description
  get "/debug/api" do
    if should_handle_route?(conn, [:debug, :inspect]) do
      # Build the API endpoints based on the current mode
      endpoints = [
        %{
          path: "/",
          method: "GET",
          description: "Returns server status and mode information"
        },
        %{
          path: "/sse",
          method: "GET",
          description: "Establishes a Server-Sent Events (SSE) connection to the MCP server"
        },
        %{
          path: "/rpc",
          method: "POST",
          description: "Sends a JSON-RPC request to the MCP server (requires session_id query parameter)"
        },
        %{
          path: "/rpc/:session_id",
          method: "POST",
          description: "Sends a JSON-RPC request to the MCP server for a specific session"
        },
        %{
          path: "/debug/:session_id",
          method: "GET",
          description: "Returns debugging information about a specific session"
        },
        %{
          path: "/debug/sessions",
          method: "GET",
          description: "Lists all active sessions"
        },
        %{
          path: "/debug/api",
          method: "GET",
          description: "Returns this API description"
        }
      ]

      # Add inspector endpoints if in inspect mode
      endpoints = if current_mode(conn) == :inspect do
        endpoints ++ [
          %{
            path: "/inspector",
            method: "GET",
            description: "Provides a web interface for inspecting and debugging MCP protocol messages"
          },
          %{
            path: "/debug/tool/:tool_name",
            method: "GET",
            description: "Provides a web interface for testing a specific tool"
          }
        ]
      else
        endpoints
      end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{
        endpoints: endpoints,
        mode: current_mode(conn)
      }))
    else
      not_found(conn)
    end
  end

  # The following routes are only available in :inspect mode

  # MCP Inspector UI
  get "/inspector" do
    if should_handle_route?(conn, [:inspect]) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, inspector_html())
    else
      not_found(conn)
    end
  end

  # Debug UI for testing tools
  get "/debug/tool/:tool_name" do
    if should_handle_route?(conn, [:inspect]) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, debug_tool_html(tool_name))
    else
      not_found(conn)
    end
  end

  # Catch-all route
  match _ do
    not_found(conn)
  end

  # Private functions

  defp should_handle_route?(conn, allowed_modes) do
    current_mode(conn) in allowed_modes
  end

  defp not_found(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end

  defp handle_rpc_request(conn, session_id) do
    {:ok, body, conn} = read_body(conn)

    # Parse the JSON-RPC request
    case Jason.decode(body) do
      {:ok, request} ->
        # Handle the request
        case Server.handle_message(session_id, request) do
          {:ok, nil} ->
            # This was a notification, no response needed
            conn
            |> send_resp(204, "")

          {:ok, response} ->
            # Return the response
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(response))

          {:error, {code, message, data}} ->
            # Return the error
            error_response = %{
              jsonrpc: "2.0",
              error: %{
                code: code,
                message: message,
                data: data
              },
              id: request["id"]
            }

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(error_response))
        end

      {:error, _} ->
        # Invalid JSON
        error_response = %{
          jsonrpc: "2.0",
          error: %{
            code: -32700,
            message: "Parse error",
            data: nil
          },
          id: nil
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(error_response))
    end
  end

  defp redact_sensitive_data(data) do
    # Remove sensitive data from the session data
    # In a real implementation, you would redact sensitive data
    data
  end

  defp inspector_html do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>GraphOS MCP Inspector</title>
      <style>
        body {
          font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
        }
        h1, h2 { color: #333; }
        .container {
          display: flex;
          flex-direction: column;
          height: 100vh;
        }
        #inspector-container {
          flex-grow: 1;
          margin-top: 20px;
          border: 1px solid #ddd;
          border-radius: 4px;
          min-height: 500px;
        }
        .info {
          background-color: #f0f8ff;
          padding: 12px;
          border-radius: 4px;
          margin-bottom: 16px;
        }
        pre { background: #f5f5f5; padding: 10px; border-radius: 4px; }
        button { padding: 8px 16px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer; margin-top: 10px; }
        button:hover { background: #45a049; }
        input { width: 100%; padding: 8px; margin: 8px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>GraphOS MCP Inspector</h1>

        <div class="info">
          <p>This page embeds the MCP Inspector to debug MCP protocol messages.</p>
          <p>Connection URL: <code id="connection-url">http://localhost:4000/sse</code></p>
        </div>

        <div id="connection-form">
          <h2>Connection Settings</h2>
          <label for="sse-url">SSE Endpoint URL:</label>
          <input type="text" id="sse-url" value="/sse">
          <button id="load-inspector">Load Inspector</button>
        </div>

        <div id="inspector-container"></div>
      </div>

      <script>
        document.getElementById('load-inspector').addEventListener('click', () => {
          const sseUrl = document.getElementById('sse-url').value;
          loadInspector(sseUrl);
        });

        function loadInspector(sseUrl) {
          // Update the display URL
          document.getElementById('connection-url').textContent = new URL(sseUrl, window.location.origin).href;

          // Create a script element to load the MCP Inspector
          const script = document.createElement('script');
          script.src = 'https://cdn.jsdelivr.net/npm/@modelcontextprotocol/inspector@latest/dist/index.js';
          script.onload = () => {
            const container = document.getElementById('inspector-container');

            // Clear previous content
            container.innerHTML = '';

            // Check if the MCPInspector global is available
            if (window.MCPInspector) {
              try {
                // Configure the inspector to use our SSE URL
                const inspector = new window.MCPInspector({
                  container: container,
                  serverUrl: sseUrl
                });

                // Start the inspector
                inspector.start();
              } catch (error) {
                container.innerHTML = `<div class="error">Error initializing MCP Inspector: ${error.message}</div>`;
              }
            } else {
              container.innerHTML = '<div class="error">MCP Inspector failed to load. Check console for errors.</div>';
            }
          };

          script.onerror = () => {
            document.getElementById('inspector-container').innerHTML =
              '<div class="error">Failed to load MCP Inspector from CDN. Check your internet connection.</div>';
          };

          // Add the script to the document
          document.body.appendChild(script);
        }
      </script>
    </body>
    </html>
    """
  end

  defp debug_tool_html(tool_name) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>MCP Tool Debug - #{tool_name}</title>
      <style>
        body {
          font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
        }
        h1 { color: #333; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 4px; }
        button { padding: 8px 16px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #45a049; }
        input, textarea { width: 100%; padding: 8px; margin: 8px 0; }
        #response { margin-top: 20px; }
      </style>
    </head>
    <body>
      <h1>MCP Tool Debug: #{tool_name}</h1>

      <div>
        <h2>Session Setup</h2>
        <div>
          <label for="session-id">Session ID:</label>
          <input type="text" id="session-id" placeholder="Enter session ID or leave empty to create new">
          <button id="connect">Connect</button>
        </div>
      </div>

      <div>
        <h2>Tool Parameters</h2>
        <div>
          <label for="tool-params">Parameters (JSON):</label>
          <textarea id="tool-params" rows="5">{"key": "value"}</textarea>
        </div>
        <button id="call-tool">Call Tool</button>
      </div>

      <div id="response">
        <h2>Response</h2>
        <pre id="response-data">No response yet</pre>
      </div>

      <script>
        let sessionId = '';
        let eventSource = null;

        document.getElementById('connect').addEventListener('click', () => {
          const inputSessionId = document.getElementById('session-id').value.trim();

          if (eventSource) {
            eventSource.close();
          }

          // Create SSE connection
          const url = inputSessionId ? `/sse?session_id=${inputSessionId}` : '/sse';
          eventSource = new EventSource(url);

          eventSource.onopen = () => {
            console.log('SSE connection opened');
          };

          eventSource.addEventListener('message', (event) => {
            const data = JSON.parse(event.data);
            console.log('SSE message:', data);

            if (data.session_id) {
              sessionId = data.session_id;
              document.getElementById('session-id').value = sessionId;
            }

            document.getElementById('response-data').textContent = JSON.stringify(data, null, 2);
          });

          eventSource.onerror = (error) => {
            console.error('SSE error:', error);
            document.getElementById('response-data').textContent = 'SSE connection error';
          };
        });

        document.getElementById('call-tool').addEventListener('click', async () => {
          if (!sessionId) {
            alert('Please connect to a session first');
            return;
          }

          try {
            const params = JSON.parse(document.getElementById('tool-params').value);

            const request = {
              jsonrpc: "2.0",
              method: "callTool",
              params: {
                name: "#{tool_name}",
                arguments: params
              },
              id: Date.now().toString()
            };

            const response = await fetch(`/rpc/${sessionId}`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(request)
            });

            const responseData = await response.json();
            document.getElementById('response-data').textContent = JSON.stringify(responseData, null, 2);
          } catch (error) {
            document.getElementById('response-data').textContent = `Error: ${error.message}`;
          }
        });
      </script>
    </body>
    </html>
    """
  end

  # Helper function for SSE connections
  defp send_sse_data(conn, session_id, initial_data) do
    # Register this connection in the registry
    SSE.ConnectionRegistry.register(session_id, self(), %{
      protocol_version: nil,
      capabilities: %{},
      initialized: false,
      tools: %{}
    })

    # Send the initial data as a message event
    data = Jason.encode!(initial_data)
    chunk(conn, "event: message\ndata: #{data}\n\n")

    # Keep the connection open
    Process.sleep(:infinity)
    conn
  end
end
