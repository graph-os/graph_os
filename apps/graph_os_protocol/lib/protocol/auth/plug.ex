defmodule GraphOS.Protocol.Auth.Plug do
  @moduledoc """
  Authentication plug for GraphOS protocol endpoints.

  This plug enforces the RPC secret authentication for protocol endpoints.
  It extracts the secret from request headers or context and validates it
  against the configured secret.

  ## Usage

  Add this plug to your GraphOS protocol adapter's plug pipeline:

  ```elixir
  # In your adapter configuration
  GraphOS.Protocol.GRPC.start_link(
    name: MyGRPCAdapter,
    schema_module: MyApp.GraphSchema,
    plugs: [
      GraphOS.Protocol.Auth.Plug,  # Add the auth plug
      {AuthPlug, realm: "api"},
      LoggingPlug
    ]
  )
  ```

  Or in a Phoenix/Plug router:

  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug GraphOS.Protocol.Auth.Plug  # Add the auth plug
  end
  ```
  """

  import Plug.Conn
  alias GraphOS.Protocol.Auth.Secret

  @jason_available? Code.ensure_loaded?(Jason)

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract the secret from the context
    secret = extract_secret(conn)

    # Validate the secret
    case Secret.validate(secret) do
      :ok ->
        # Secret is valid or not required, continue the pipeline
        conn

      {:error, reason} ->
        # Authentication failed, halt the pipeline with an error
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, json_error("Authentication failed: #{reason}"))
        |> halt()
    end
  end

  # Extract the secret from different types of requests
  defp extract_secret(conn) do
    cond do
      # If it's a standard Plug.Conn
      match?(%Plug.Conn{}, conn) ->
        # Try to extract from HTTP headers first
        secret_from_conn_headers(conn) || conn.assigns[:rpc_secret]

      # If it has HTTP headers (for JSON-RPC and REST)
      has_http_headers?(conn) ->
        get_secret_from_headers(conn)

      # If it has gRPC metadata
      has_grpc_metadata?(conn) ->
        get_secret_from_grpc_metadata(conn)

      # Try to extract from context assigns (for custom transport)
      has_secret_in_assigns?(conn) ->
        get_secret_from_assigns(conn)

      # No secret found
      true ->
        nil
    end
  end

  # Extract secret from Plug.Conn headers
  defp secret_from_conn_headers(conn) do
    conn
    |> get_req_header("x-graph-os-rpc-secret")
    |> case do
      [value | _] ->
        value

      [] ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token | _] -> token
          _ -> nil
        end
    end
  end

  # Check for HTTP headers in context
  defp has_http_headers?(context) do
    is_map(context) and is_map(context.req_headers)
  end

  # Extract secret from HTTP headers
  defp get_secret_from_headers(context) do
    # Check for our custom header or Authorization header
    headers = context.req_headers || %{}

    case headers do
      %{"x-graph-os-rpc-secret" => secret} when is_binary(secret) ->
        secret

      %{"authorization" => "Bearer " <> token} ->
        token

      _ ->
        nil
    end
  end

  # Check for gRPC metadata in context
  defp has_grpc_metadata?(context) do
    is_map(context) and is_map(context.metadata)
  end

  # Extract secret from gRPC metadata
  defp get_secret_from_grpc_metadata(context) do
    metadata = context.metadata || %{}

    case metadata do
      %{"x-graph-os-rpc-secret" => secret} when is_binary(secret) ->
        secret

      %{"authorization" => "Bearer " <> token} ->
        token

      _ ->
        nil
    end
  end

  # Check for secret in assigns (for custom transport)
  defp has_secret_in_assigns?(context) do
    is_map(context) and is_map(context.assigns) and Map.has_key?(context.assigns, :rpc_secret)
  end

  # Extract secret from assigns
  defp get_secret_from_assigns(context) do
    context.assigns.rpc_secret
  end

  # Helper for JSON encoding error messages
  defp json_error(message) when is_binary(message) do
    if @jason_available? do
      Jason.encode!(%{error: message})
    else
      # Fallback if Jason is not available
      "{\"error\": \"#{message}\"}"
    end
  end
end
