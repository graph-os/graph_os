 defmodule GraphOS.Protocol.Router do
  @moduledoc """
  Main Plug router for handling GraphOS protocol requests, including SSE.
  """
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Jason
  plug :fetch_query_params # Ensure query params are parsed before forwarding
  plug :dispatch

  # Simple test route
  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  # Forward all /sse requests (initial connection) to the dedicated SSE/MCP Plug
  forward "/sse", to: SSE.ConnectionPlug

  # Forward /rpc/:session_id requests (subsequent messages) to the same plug
  forward "/rpc/:session_id", to: SSE.ConnectionPlug

  # Catch-all for other requests
  match _ do
    # Log any request that falls through the pipeline (wasn't handled by SSE.ConnectionPlug)
    require Logger
    Logger.warning("Unhandled request received: #{inspect conn.method} #{inspect conn.request_path} Query: #{inspect conn.query_string}")
    # Optionally inspect headers or body if needed for debugging
    # Logger.debug("Unhandled request headers: #{inspect conn.req_headers}")

     # Send a 404 Not Found response
     conn
     |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not Found")
    end

   # Removed custom logging plug
  end
