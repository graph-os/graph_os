defmodule SSE.ConnectionPlug do
  @moduledoc """
  Plug for handling SSE connections and JSON-RPC message requests.

  This plug handles both:
  - GET requests to establish SSE connections
  - POST requests to process JSON-RPC messages

  It ensures that all requests have a valid session ID and routes
  messages to the appropriate handlers.
  """

  import Plug.Conn
  alias MCP.Server

  @doc """
  Initialize options for the plug.
  """
  def init(opts), do: opts

  @doc """
  Main entry point for the plug.

  Handles both SSE connections (GET) and message requests (POST).
  """
  def call(%{method: "GET"} = conn, _opts) do
    session_id = get_session_id(conn)

    if session_id do
      handle_sse_connection(conn, session_id)
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "Missing sessionId parameter"}))
    end
  end

  def call(%{method: "POST"} = conn, _opts) do
    session_id = get_session_id(conn)

    if session_id do
      handle_message_request(conn, session_id)
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "Missing sessionId parameter"}))
    end
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(405, Jason.encode!(%{error: "Method not allowed"}))
  end

  # Private functions

  defp get_session_id(conn) do
    case conn.query_params["sessionId"] do
      nil -> nil
      "" -> nil
      session_id -> session_id
    end
  end

  defp handle_sse_connection(conn, session_id) do
    SSE.log(:info, "New SSE connection", session_id: session_id)

    # Set up SSE connection
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Register the connection
    {:ok, _} = Task.start(fn -> start_sse_process(conn, session_id) end)

    # Keep the connection alive
    Process.sleep(:infinity)
    conn
  end

  defp start_sse_process(conn, session_id) do
    # Register this process in the registry
    SSE.ConnectionRegistry.register(session_id, self(), %{
      protocol_version: nil,
      capabilities: %{},
      initialized: false,
      tools: %{}
    })

    # Send the initial event with message endpoint info
    message_endpoint = "/message?sessionId=#{session_id}"
    send_sse_event(conn, "endpoint", message_endpoint)

    # Start the server for this session
    Server.start(session_id)
  end

  defp handle_message_request(conn, session_id) do
    SSE.log(:debug, "Received message request", session_id: session_id)

    with {:ok, body, conn} <- read_body(conn),
         {:ok, message} <- parse_message(body),
         {:ok, result} <- process_message(session_id, message) do
      SSE.log(:debug, "Message processed successfully",
        session_id: session_id,
        request_id: message["id"],
        method: message["method"]
      )

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(result))
    else
      {:error, :invalid_json} ->
        SSE.log(:warn, "Invalid JSON in request", session_id: session_id)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{
            jsonrpc: "2.0",
            error: %{
              code: -32700,
              message: "Parse error: Invalid JSON"
            }
          })
        )

      {:error, errors} when is_list(errors) ->
        SSE.log(:warn, "Invalid JSON-RPC message",
          session_id: session_id,
          errors: errors
        )

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{
            jsonrpc: "2.0",
            error: %{
              code: -32600,
              message: "Invalid Request: #{inspect(errors)}"
            }
          })
        )

      {:error, {code, message, data}} ->
        SSE.log(:warn, "Error processing message",
          session_id: session_id,
          code: code,
          message: message
        )

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{
            jsonrpc: "2.0",
            id: message["id"],
            error: %{
              code: code,
              message: message,
              data: data
            }
          })
        )
    end
  end

  defp parse_message(body) do
    case Jason.decode(body) do
      {:ok, message} -> {:ok, message}
      {:error, _reason} -> {:error, "Invalid JSON"}
    end
  end

  defp process_message(session_id, message) do
    Server.handle_message(session_id, message)
  end

  @doc """
  Send a JSON-RPC message to the client over SSE.

  ## Parameters

  * `conn` - The connection
  * `message` - The message to send (will be encoded as JSON)
  """
  def send_message(conn, message) do
    SSE.log(:debug, "Sending message",
      message: inspect(message)
    )

    data = Jason.encode!(message)
    send_sse_event(conn, "message", data)
  end

  @doc """
  Sends an SSE event to the client.

  ## Parameters

  * `conn` - The connection
  * `event` - The event name
  * `data` - The event data
  """
  def send_sse_event(conn, event, data) do
    SSE.log(:debug, "Sending SSE event",
      event: event,
      data: inspect(data)
    )

    chunk = "event: #{event}\ndata: #{data}\n\n"
    chunk(conn, chunk)
  end
end
