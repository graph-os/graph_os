defmodule MCP.Endpoint do
  @moduledoc """
  A reusable MCP server endpoint.

  This module provides a complete, ready-to-use MCP server endpoint that can be
  included in other applications. It uses the MCP.DefaultServer implementation
  by default, but can be configured to use a custom server.

  ## Example

      # In your application supervision tree
      children = [
        {MCP.Endpoint,
          server: MyApp.CustomMCPServer,
          port: 4000,
          mode: :debug
        }
      ]

  ## Options

  * `:server` - The MCP server module to use (default: MCP.DefaultServer)
  * `:port` - The port to listen on (default: 4000)
  * `:mode` - The mode to use (`:sse`, `:debug`, or `:inspect`) (default: `:sse`)
  * `:host` - The host to bind to (default: "0.0.0.0")
  * `:path_prefix` - The URL path prefix for MCP endpoints (default: "/mcp")
  """

  use Supervisor
  require Logger

  @doc """
  Starts the MCP server endpoint.

  ## Options

  * `:server` - The MCP server module to use (default: MCP.DefaultServer)
  * `:port` - The port to listen on (default: 4000)
  * `:mode` - The mode to use (`:sse`, `:debug`, or `:inspect`) (default: `:sse`)
  * `:host` - The host to bind to (default: "0.0.0.0")
  * `:path_prefix` - The URL path prefix for MCP endpoints (default: "/mcp")
  """
  def start_link(opts \\ []) do
    server = Keyword.get(opts, :server, MCP.DefaultServer)
    port = Keyword.get(opts, :port, 4000)
    mode = Keyword.get(opts, :mode, :sse)
    host = Keyword.get(opts, :host, "0.0.0.0")
    path_prefix = Keyword.get(opts, :path_prefix, "/mcp")

    # Store configuration for the router
    Application.put_env(:mcp, :endpoint, %{
      server: server,
      mode: mode,
      path_prefix: path_prefix
    })

    Supervisor.start_link(__MODULE__, {port, host}, name: __MODULE__)
  end

  @impl true
  def init({port, host}) do
    config = Application.get_env(:mcp, :endpoint)
    path_prefix = config.path_prefix

    # Configure the MCP router
    router = {Plug.Cowboy,
      scheme: :http,
      plug: {MCP.Router, []},
      options: [
        port: port,
        ip: parse_host(host),
        dispatch: dispatch_config(path_prefix)
      ]
    }

    children = [router]

    Logger.info("MCP Endpoint starting on #{host}:#{port}#{path_prefix} in #{config.mode} mode")

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Parse a host string into an IP tuple
  defp parse_host(host) do
    case host do
      "localhost" -> {127, 0, 0, 1}
      "0.0.0.0" -> {0, 0, 0, 0}
      h when is_binary(h) ->
        h
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)
        |> List.to_tuple()
      ip when is_tuple(ip) -> ip
    end
  end

  # Create a dispatch configuration for the Cowboy router
  defp dispatch_config(path_prefix) do
    sse_path = "#{path_prefix}/sse"
    message_path = "#{path_prefix}/message"

    [
      # SSE endpoint
      {:_, [
        {sse_path, MCP.SSEHandler, []},
        {message_path, MCP.MessageHandler, []},
        {:_, Plug.Cowboy.Handler, {MCP.Router, []}}
      ]}
    ]
  end
end

defmodule MCP.SSEHandler do
  @moduledoc """
  Handler for SSE connections.
  """

  require Logger

  def init(req, _state) do
    session_id = get_session_id(req)

    Logger.debug("SSE connection request", session_id: session_id)

    # Set appropriate headers for SSE
    req = :cowboy_req.stream_reply(200, %{
      "content-type" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"
    }, req)

    # Register the connection
    {:ok, _} = SSE.ConnectionRegistry.register(session_id, self())

    # Start the MCP server for this session
    config = Application.get_env(:mcp, :endpoint)
    server = config.server

    server.start(session_id)

    # Send the message endpoint
    path_prefix = config.path_prefix
    message_endpoint = "#{path_prefix}/message"

    send_sse_event(req, "endpoint", message_endpoint)

    # Wait for messages
    {:ok, req, %{session_id: session_id}}
  end

  def info({:sse_event, event_type, data}, req, state) do
    send_sse_event(req, event_type, data)
    {:ok, req, state}
  end

  def info(_msg, req, state) do
    {:ok, req, state}
  end

  def terminate(_reason, _req, %{session_id: session_id}) do
    Logger.debug("SSE connection terminated", session_id: session_id)
    SSE.ConnectionRegistry.unregister(session_id)
    :ok
  end

  # Get the session ID from the request
  defp get_session_id(req) do
    qs = :cowboy_req.parse_qs(req)
    case List.keyfind(qs, "sessionId", 0) do
      {"sessionId", session_id} -> session_id
      _ -> UUID.uuid4()
    end
  end

  # Send an SSE event
  defp send_sse_event(req, event_type, data) do
    event = "event: #{event_type}\ndata: #{data}\n\n"
    :cowboy_req.stream_body(event, :nofin, req)
  end
end

defmodule MCP.MessageHandler do
  @moduledoc """
  Handler for JSON-RPC messages.

  This module handles incoming JSON-RPC messages and dispatches them to the
  configured MCP server. It also handles errors and returns responses to the
  client.

  ## Using MCP.Message

  For future reference, the MCP.Message module can be used to create and parse
  JSON-RPC messages. It provides a convenient way to work with JSON-RPC messages
  and can be used to simplify the handling of messages in this module.
  """

  require Logger

  def init(req, state) do
    session_id = get_session_id(req)

    Logger.debug("Message request", session_id: session_id)

    # Read the body
    {:ok, body, req} = :cowboy_req.read_body(req)

    # Parse the JSON message
    case Jason.decode(body) do
      {:ok, message} ->
        handle_message(req, session_id, message)

      {:error, reason} ->
        # Create error response using MCP.Message
        error_response = %{
          jsonrpc: "2.0",
          error: %{
            code: -32700,
            message: "Parse error: #{inspect(reason)}"
          },
          id: nil
        }

        req = :cowboy_req.reply(400, %{
          "content-type" => "application/json"
        }, Jason.encode!(error_response), req)

        {:ok, req, state}
    end
  end

  defp handle_message(req, session_id, message) do
    config = Application.get_env(:mcp, :endpoint)
    server = config.server

    # Process the message
    case server.handle_message(session_id, message) do
      {:ok, nil} ->
        # No response for notifications
        req = :cowboy_req.reply(204, %{}, "", req)
        {:ok, req, %{}}

      {:ok, response} ->
        req = :cowboy_req.reply(200, %{
          "content-type" => "application/json"
        }, Jason.encode!(response), req)

        {:ok, req, %{}}

      {:error, {code, message, data}} ->
        error_response = %{
          jsonrpc: "2.0",
          error: %{
            code: code,
            message: message,
            data: data
          },
          id: message["id"]
        }

        req = :cowboy_req.reply(400, %{
          "content-type" => "application/json"
        }, Jason.encode!(error_response), req)

        {:ok, req, %{}}
    end
  end

  # Get the session ID from the request
  defp get_session_id(req) do
    qs = :cowboy_req.parse_qs(req)
    case List.keyfind(qs, "sessionId", 0) do
      {"sessionId", session_id} -> session_id
      _ ->
        Logger.warning("No session ID provided for message request")
        UUID.uuid4()
    end
  end
end
