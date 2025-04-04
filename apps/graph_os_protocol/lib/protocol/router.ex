defmodule GraphOS.Protocol.Router do
  @moduledoc """
  Main Plug router for handling GraphOS protocol requests, including SSE.
  """
  use Plug.Router # Use Plug.Router for defining routes/forwarding
  use Plug.Builder # Use Plug.Builder for the pipeline

  # TODO: Verify the exact option name expected by SSE.ConnectionPlug
   @sse_plug_opts [handler_module: GraphOS.Protocol.MCPImplementation]

   # Define the pipeline
    plug Plug.Parsers, parsers: [:urlencoded, :json], # Add :json parser
                       json_decoder: Jason # Specify Jason as the decoder
    # plug Plug.Logger, log: :debug
   plug SSE.ConnectionPlug, @sse_plug_opts

  # Forward all requests at the root path (or a specific path like "/mcp") to this pipeline
  # Note: Adjust path if needed. SSE.ConnectionPlug might handle specific paths internally.
  match _ do
    # Log any request that falls through the pipeline (wasn't handled by SSE.ConnectionPlug)
    require Logger
    Logger.warn("Unhandled request received: #{inspect conn.method} #{inspect conn.request_path} Query: #{inspect conn.query_string}")
    # Optionally inspect headers or body if needed for debugging
    # Logger.debug("Unhandled request headers: #{inspect conn.req_headers}")

     # Send a 404 Not Found response
     conn
     |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not Found")
    end

   # Removed custom logging plug
  end
