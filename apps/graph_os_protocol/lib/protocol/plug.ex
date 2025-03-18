defmodule GraphOS.Protocol.Plug do
  @moduledoc """
  Standard Plug implementation for GraphOS protocol integration.

  This module provides a Plug-compliant interface for GraphOS components, allowing
  them to be integrated into HTTP applications built with Plug or Phoenix. It handles
  routing, parameter parsing, authentication, and other HTTP-specific concerns.

  ## Configuration

  - `:adapter` - The GraphOS adapter to use (default: `GraphOS.Adapter.GenServer`)
  - `:adapter_opts` - Options to pass to the adapter
  - `:base_path` - Base path for all routes (default: "/graph")
  - `:json_codec` - JSON codec module to use (default: `Jason`)
  - `:schema_module` - Protocol Buffer schema module (optional, for protobuf support)

  ## HTTP Routes

  This plug exposes the following HTTP routes:

  - `GET /graph/query/:path` - Execute a graph query
  - `POST /graph/query/:path` - Execute a graph query with a request body
  - `POST /graph/action/:path` - Execute a graph action
  - `GET /graph/subscribe` - Subscribe to graph events via SSE
  - `GET /graph/jsonrpc` - JSON-RPC endpoint (GET for discovery)
  - `POST /graph/jsonrpc` - JSON-RPC endpoint (POST for requests)
  - `POST /graph/protobuf/:method` - Protocol Buffer endpoint

  use Boundary, deps: [:graph_os_core, :graph_os_graph]

  ## Upgradable Protocol System

  This plug supports the upgradable protocol system, allowing Protocol Buffers to be
  used as the canonical schema definition but accessed via different protocols:

  1. **Direct Protocol Buffer access**:
  ```
  POST /graph/protobuf/:method
  Content-Type: application/x-protobuf
  Accept: application/x-protobuf

  <binary protobuf data>
  ```

  2. **Protocol Buffer to JSON-RPC upgrade**:
  ```
  POST /graph/protobuf/:method
  Content-Type: application/x-protobuf
  Accept: application/json

  <binary protobuf data>
  ```

  3. **JSON-RPC access (internally uses Protocol Buffers)**:
  ```
  POST /graph/jsonrpc
  Content-Type: application/json

  {"jsonrpc": "2.0", "method": "graph.query.nodes.get", "params": {"id": "123"}, "id": 1}
  ```

  The system uses Protocol Buffers as the canonical schema definition, ensuring
  type safety and consistency across all protocols. As of now, the Protocol Buffer
  support is being implemented as part of HANDOFFS-001.

  ## Usage

  ```elixir
  # In a Phoenix router
  pipeline :api do
    plug :accepts, ["json", "protobuf"]
    # ...
  end

  scope "/api" do
    pipe_through :api
    
    forward "/graph", GraphOS.Protocol.Plug, [
      adapter_opts: [
        graph_module: MyApp.Graph,
        schema_module: MyApp.GraphSchema,
        plugs: [
          {MyApp.AuthPlug, realm: "api"},
          MyApp.LoggingPlug
        ]
      ],
      json_codec: Jason
    ]
  end
  ```

  Or in a simple Plug application:

  ```elixir
  defmodule MyApp.Router do
    use Plug.Router
    
    plug :match
    plug :dispatch
    
    forward "/graph", GraphOS.Protocol.Plug, [
      adapter_opts: [
        graph_module: MyApp.Graph,
        schema_module: MyApp.GraphSchema
      ]
    ]
    
    match _ do
      send_resp(conn, 404, "Not found")
    end
  end
  ```
  """

  @behaviour Plug
  alias GraphOS.Adapter.{Context, GenServer}

  @impl true
  def init(opts) do
    # Get schema module from adapter_opts if available
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    schema_module =
      Keyword.get(adapter_opts, :schema_module) ||
        Keyword.get(opts, :schema_module)

    # Default options
    %{
      adapter: Keyword.get(opts, :adapter, GenServer),
      adapter_opts: adapter_opts,
      base_path: Keyword.get(opts, :base_path, "/graph"),
      json_codec: Keyword.get(opts, :json_codec, Jason),
      schema_module: schema_module
    }
  end

  @impl true
  def call(conn, opts) do
    # Check if an adapter is already started
    adapter =
      case conn.private[:graphos_adapter] do
        nil ->
          # Start the adapter
          {:ok, adapter} = start_adapter(opts)
          adapter

        adapter ->
          # Use the existing adapter
          adapter
      end

    # Add the adapter to the connection
    conn = Plug.Conn.put_private(conn, :graphos_adapter, adapter)

    # Route the request
    route_request(conn, opts)
  end

  # Start a new adapter instance
  defp start_adapter(opts) do
    adapter_module = opts.adapter
    adapter_opts = opts.adapter_opts

    # Start the adapter linked to the current process
    adapter_module.start_link(adapter_opts)
  end

  # Route the request based on the path and method
  defp route_request(conn, opts) do
    base_path = opts.base_path
    path_info = conn.path_info

    case {conn.method, path_info} do
      {"GET", [^base_path, "query", path]} ->
        # Query with URL parameters
        params = normalize_params(conn.query_params)
        handle_query(conn, path, params, opts)

      {"POST", [^base_path, "query", path]} ->
        # Query with request body
        {:ok, params, conn} = read_body(conn, opts)
        handle_query(conn, path, params, opts)

      {"POST", [^base_path, "action", path]} ->
        # Action with request body
        {:ok, params, conn} = read_body(conn, opts)
        handle_action(conn, path, params, opts)

      {"GET", [^base_path, "subscribe"]} ->
        # Subscribe to events via SSE
        handle_subscribe(conn, opts)

      {"GET", [^base_path, "jsonrpc"]} ->
        # JSON-RPC endpoint (discovery)
        handle_jsonrpc_discovery(conn, opts)

      {"POST", [^base_path, "jsonrpc"]} ->
        # JSON-RPC endpoint (requests)
        {:ok, request, conn} = read_body(conn, opts)
        handle_jsonrpc_request(conn, request, opts)

      {"POST", [^base_path, "protobuf", method]} ->
        # Protocol Buffer endpoint for the upgradable protocol system
        handle_protobuf_request(conn, method, opts)

      _ ->
        # Unknown route
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, encode_json(%{error: "Not found"}, opts))
    end
  end

  # Handle a graph query
  defp handle_query(conn, path, params, opts) do
    adapter = conn.private[:graphos_adapter]

    # Create a context with request data
    context =
      Context.new(
        request_id: "plug-#{:erlang.system_time(:microsecond)}",
        params: %{
          method: conn.method,
          path: conn.request_path,
          headers: conn.req_headers,
          query_params: conn.query_params
        }
      )

    # Execute the query
    case GenServer.execute(adapter, {:query, path, params}, context) do
      {:ok, result} ->
        # Query succeeded
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, encode_json(result, opts))

      {:error, reason} ->
        # Query failed
        {status, error} = error_to_response(reason)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, encode_json(error, opts))
    end
  end

  # Handle a graph action
  defp handle_action(conn, path, params, opts) do
    adapter = conn.private[:graphos_adapter]

    # Create a context with request data
    context =
      Context.new(
        request_id: "plug-#{:erlang.system_time(:microsecond)}",
        params: %{
          method: conn.method,
          path: conn.request_path,
          headers: conn.req_headers,
          body: params
        }
      )

    # Execute the action
    case GenServer.execute(adapter, {:action, path, params}, context) do
      {:ok, result} ->
        # Action succeeded
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, encode_json(result, opts))

      {:error, reason} ->
        # Action failed
        {status, error} = error_to_response(reason)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, encode_json(error, opts))
    end
  end

  # Handle event subscription via SSE
  defp handle_subscribe(conn, _opts) do
    # Not implemented yet
    # This would set up a Server-Sent Events connection
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(501, encode_json(%{error: "Not implemented"}, %{json_codec: Jason}))
  end

  # Handle JSON-RPC discovery
  defp handle_jsonrpc_discovery(conn, opts) do
    # Return information about the JSON-RPC service
    response = %{
      jsonrpc: "2.0",
      result: %{
        name: "GraphOS JSON-RPC API",
        version: "1.0.0",
        methods: [
          "graph.query.*",
          "graph.action.*",
          "graph.subscribe",
          "graph.unsubscribe"
        ]
      }
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, encode_json(response, opts))
  end

  # Handle a JSON-RPC request
  defp handle_jsonrpc_request(conn, request, opts) do
    adapter = conn.private[:graphos_adapter]

    # Create a context with request data
    context =
      Context.new(
        request_id: "plug-#{:erlang.system_time(:microsecond)}",
        params: %{
          method: conn.method,
          path: conn.request_path,
          headers: conn.req_headers,
          body: request
        }
      )

    # Process the JSON-RPC request through the JSONRPC adapter
    case GraphOS.Protocol.JSONRPC.process(adapter, request, context) do
      {:ok, response} ->
        # Request succeeded
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, encode_json(response, opts))

      {:error, reason} ->
        # Request failed
        {status, error} = error_to_response(reason)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, encode_json(error, opts))
    end
  end

  # Handle a Protocol Buffer request
  defp handle_protobuf_request(conn, method, opts) do
    # We need a schema module to handle protobuf requests
    if opts.schema_module do
      adapter = conn.private[:graphos_adapter]
      accept_type = get_accept_type(conn)

      # Read and parse the request body
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      # Create a context with request data
      context =
        Context.new(
          request_id: "plug-#{:erlang.system_time(:microsecond)}",
          params: %{
            method: conn.method,
            path: conn.request_path,
            headers: conn.req_headers,
            body: body
          }
        )

      # Decode the protobuf request
      case decode_protobuf(body, [method], opts) do
        {:ok, request} ->
          # Process the request through the gRPC adapter
          case GraphOS.Protocol.GRPC.process(adapter, request, method, context) do
            {:ok, response} ->
              # Request succeeded - determine how to encode the response
              case accept_type do
                accept when accept in ["application/x-protobuf", "application/protobuf"] ->
                  # Return as Protocol Buffer
                  conn
                  |> Plug.Conn.put_resp_content_type("application/x-protobuf")
                  |> Plug.Conn.send_resp(200, encode_protobuf(response))

                accept when accept in ["application/json", "text/json"] ->
                  # Return as JSON
                  {:ok, json_response} =
                    GraphOS.Protocol.GRPC.upgrade(adapter, response, method, :jsonrpc)

                  conn
                  |> Plug.Conn.put_resp_content_type("application/json")
                  |> Plug.Conn.send_resp(200, encode_json(json_response, opts))

                _ ->
                  # Default to JSON
                  {:ok, json_response} =
                    GraphOS.Protocol.GRPC.upgrade(adapter, response, method, :jsonrpc)

                  conn
                  |> Plug.Conn.put_resp_content_type("application/json")
                  |> Plug.Conn.send_resp(200, encode_json(json_response, opts))
              end

            {:error, reason} ->
              # Request failed
              {status, error} = error_to_response(reason)

              conn
              |> Plug.Conn.put_resp_content_type("application/json")
              |> Plug.Conn.send_resp(status, encode_json(error, opts))
          end

        {:error, reason} ->
          # Failed to decode protobuf
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            400,
            encode_json(%{error: "Invalid Protocol Buffer: #{inspect(reason)}"}, opts)
          )
      end
    else
      # No schema module available
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        501,
        encode_json(%{error: "Protocol Buffer support not configured"}, opts)
      )
    end
  end

  # Helper functions

  # Read the request body and parse it based on content type
  defp read_body(conn, opts) do
    content_type = get_content_type(conn)

    case content_type do
      "application/x-protobuf" ->
        read_body_protobuf(conn, opts)

      "application/protobuf" ->
        read_body_protobuf(conn, opts)

      _ ->
        # Default to JSON for all other content types
        read_body_json(conn, opts)
    end
  end

  # Read and parse the request body as JSON
  defp read_body_json(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case decode_json(body, opts) do
      {:ok, params} -> {:ok, params, conn}
      # Default to empty params on parse error
      {:error, _} -> {:ok, %{}, conn}
    end
  end

  # Read and parse the request body as Protocol Buffer
  defp read_body_protobuf(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    # If we have a schema module, use it to decode the protobuf
    if opts.schema_module do
      case decode_protobuf(body, conn.path_info, opts) do
        {:ok, proto_struct} ->
          # Convert to a map for consistent processing
          params = proto_struct |> Map.from_struct() |> Map.delete(:__struct__)
          {:ok, params, conn}

        {:error, _reason} ->
          # Return empty params on parse error
          {:ok, %{}, conn}
      end
    else
      # No schema module available, treat as binary
      {:ok, %{binary: body}, conn}
    end
  end

  # Get the content type header
  defp get_content_type(conn) do
    case Plug.Conn.get_req_header(conn, "content-type") do
      [content_type | _] -> content_type
      # Default to JSON
      _ -> "application/json"
    end
  end

  # Get the accept header
  defp get_accept_type(conn) do
    case Plug.Conn.get_req_header(conn, "accept") do
      [accept | _] -> accept
      # Default to JSON
      _ -> "application/json"
    end
  end

  # Normalize parameters (strings to atoms for keys)
  defp normalize_params(params) when is_map(params) do
    params
  end

  # Encode data as JSON
  defp encode_json(data, opts) do
    json_codec = opts.json_codec
    json_codec.encode!(data)
  end

  # Decode JSON data
  defp decode_json(data, opts) do
    json_codec = opts.json_codec
    json_codec.decode(data)
  end

  # Decode Protocol Buffer data
  defp decode_protobuf(binary, path_info, opts) do
    schema_module = opts.schema_module

    if schema_module do
      # Use the schema module to get the message type for this RPC method
      rpc_name = List.first(path_info)
      msg_type = get_message_type_for_rpc(schema_module, rpc_name)

      if msg_type do
        # Use the Protobuf module to decode the binary
        try do
          decoded = GraphOS.Graph.Schema.Protobuf.decode(binary, msg_type)
          {:ok, decoded}
        rescue
          e -> {:error, {:decode_error, e.message}}
        end
      else
        {:error, {:unknown_message_type, rpc_name}}
      end
    else
      {:error, :schema_module_missing}
    end
  end

  # Encode data as Protocol Buffer
  defp encode_protobuf(proto_struct) do
    # Use the Protobuf module to encode the struct
    try do
      GraphOS.Graph.Schema.Protobuf.encode(proto_struct)
    rescue
      _ -> raise "Failed to encode Protocol Buffer message"
    end
  end

  # Get the appropriate message type for an RPC method
  defp get_message_type_for_rpc(schema_module, rpc_name) do
    if function_exported?(schema_module, :get_message_type_for_rpc, 1) do
      schema_module.get_message_type_for_rpc(rpc_name)
    else
      # Default behavior - try to infer the message type from the RPC name
      # This assumes a naming convention like GetNodeRequest -> NodeRequest
      proto_module = schema_module.protobuf_module()

      # Try to find a matching request type in the module
      request_type = "#{rpc_name}Request"

      if Code.ensure_loaded?(proto_module) do
        # Look for the request type in the module
        request_module = Module.concat(proto_module, request_type)

        if Code.ensure_loaded?(request_module) do
          request_module
        else
          nil
        end
      else
        nil
      end
    end
  end

  # Convert an error to an HTTP response
  defp error_to_response(reason) do
    case reason do
      {:not_found, _} ->
        {404, %{error: "Not found"}}

      {:unauthorized, _} ->
        {401, %{error: "Unauthorized"}}

      {:validation_error, details} ->
        {400, %{error: "Validation error", details: details}}

      {:unknown_path, path} ->
        {404, %{error: "Unknown path: #{path}"}}

      {:internal_error, _} ->
        {500, %{error: "Internal server error"}}

      {:decode_error, message} ->
        {400, %{error: "Protocol Buffer decode error", details: message}}

      {:unknown_message_type, rpc_name} ->
        {400, %{error: "Unknown message type for RPC: #{rpc_name}"}}

      :schema_module_missing ->
        {501, %{error: "Protocol Buffer support not configured"}}

      _ ->
        {500, %{error: "Unexpected error"}}
    end
  end
end
