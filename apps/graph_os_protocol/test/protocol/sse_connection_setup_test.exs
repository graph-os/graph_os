# Main test module
defmodule GraphOS.Protocol.SSEConnectionSetupTest do
  # Use the shared case template for server setup/teardown
  use GraphOS.Protocol.Test.McpServerCase, async: false

  require Logger

  # No explicit setup block needed here anymore

  # Test 1: SSE Connection using TCP Socket - Verify headers and endpoint event
  test "connects to SSE endpoint, verifies headers, and receives endpoint event", %{port: port} do # Get port from context
    Logger.info("[Test 1] Testing SSE endpoint connection, headers, and endpoint event on port: #{port}")

    # Use a simple socket approach with timeout to prevent hanging
    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false], 1000)

    # Send a simple HTTP request (without using libraries that might hang)
    request = "GET /sse HTTP/1.1\r\nHost: localhost:#{port}\r\nConnection: keep-alive\r\n\r\n"
    :ok = :gen_tcp.send(socket, request)

    # Receive the headers only (won't wait for the full body)
    {:ok, response} = :gen_tcp.recv(socket, 0, 1000)

    # Parse out the headers to verify
    [status_line | header_lines] = String.split(response, "\r\n")

    # Check if we got a 200 OK
    assert String.starts_with?(status_line, "HTTP/1.1 200"),
      "Expected 200 OK, got: #{status_line}"

    # Check for key headers
    has_sse_content_type = Enum.any?(header_lines, fn line ->
      String.downcase(line) =~ "content-type: text/event-stream"
    end)

    has_no_cache = Enum.any?(header_lines, fn line ->
      String.downcase(line) =~ "cache-control: no-cache"
    end)

    has_keep_alive = Enum.any?(header_lines, fn line ->
      String.downcase(line) =~ "connection: keep-alive"
    end)

    assert has_sse_content_type, "Missing text/event-stream content type header"
    assert has_no_cache, "Missing no-cache header"
    assert has_keep_alive, "Missing keep-alive connection header"

    Logger.info("[Test 1] Successfully verified SSE connection and headers.")

    # Now, receive the endpoint event from the socket
    {:ok, body_data} = :gen_tcp.recv(socket, 0, 1000)

    Logger.debug("[Test 1] Received data on SSE socket after headers: #{inspect(body_data)}")

    # Check for endpoint event
    assert String.contains?(body_data, "event: endpoint"),
      "Missing endpoint event in response body"
    assert String.contains?(body_data, "data: /rpc/"),
      "Missing RPC path in endpoint event"

    Logger.info("[Test 1] Successfully received endpoint event.")

    # Close the socket now
    :gen_tcp.close(socket)
  end

  # Test 0: Basic Ping/Pong - using Finch instead of Mint directly for simplicity
  test "connects and receives pong from /ping", %{endpoint_data: endpoint_data} do
    port = endpoint_data.port
    Logger.info("[Test 0] Starting. Testing /ping endpoint on port: #{port}")

    # Create a Finch pool for our test
    finch_name = :test_finch
    start_supervised!({Finch, name: finch_name})

    # Build and send a request to the ping endpoint
    url = "http://localhost:#{port}/ping"
    request = Finch.build(:get, url)

    # Send the request and get the response
    {:ok, response} = Finch.request(request, finch_name)

    # Verify the response
    assert response.status == 200, "Expected 200 status code, got #{response.status}"
    assert response.body == "pong", "Expected 'pong' response, got: #{response.body}"

    Logger.info("[Test 0] Successfully received 200 OK and 'pong' body.")
  end

  # Test 2: Receive First Event (Placeholder)
  # test "receives endpoint event after headers", %{port: port} do
  #   # ... implementation ...
  # end

  # Test 3: Initialize Request/Response (Placeholder)
  # test "sends initialize POST and receives 204 No Content", %{port: port} do
  #   # ... implementation ...
  # end

  # Test 4: Initialize Result Event (Placeholder)
  # test "receives InitializeResult event", %{port: port} do
  #   # ... implementation ...
  # end
end
