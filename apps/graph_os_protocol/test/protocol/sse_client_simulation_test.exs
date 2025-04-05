defmodule GraphOS.Protocol.SSEClientSimulationTest do
  # Use the shared case template for server setup/teardown
  use GraphOS.Protocol.Test.McpServerCase, async: false

  require Logger

  # No explicit setup block needed here anymore

   test "simulates basic client connection", %{port: port} do # Get port from context
     Logger.info("Testing SSE connection and RPC endpoint on port: #{port}")

     # Use a simple socket-based approach to avoid hanging
     {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false], 1000)

     # Send a GET request to SSE endpoint
     request = "GET /sse HTTP/1.1\r\nHost: localhost:#{port}\r\nConnection: keep-alive\r\n\r\n"
     :ok = :gen_tcp.send(socket, request)

     # Get the initial response with headers
     {:ok, response} = :gen_tcp.recv(socket, 0, 1000)

     # Verify we got a 200 OK
     assert String.contains?(response, "HTTP/1.1 200"),
       "Expected 200 response code for SSE connection"

     # Verify content type header
     assert String.contains?(response, "text/event-stream"),
       "Missing text/event-stream content type header"

     # SSE connection should return the endpoint event quickly
     # Receive some data - should include the endpoint event
     {:ok, body_data} = :gen_tcp.recv(socket, 0, 1000)

     # Check for endpoint event
     assert String.contains?(body_data, "event: endpoint"),
       "Missing endpoint event in response body"
     assert String.contains?(body_data, "data: /rpc/"),
       "Missing RPC path in endpoint event"

     # Extract the session ID from the data
     [_, session_path] = Regex.run(~r/data: (\/rpc\/[a-f0-9-]+)/, body_data)
     session_id = String.replace_prefix(session_path, "/rpc/", "")

     Logger.info("Successfully received SSE headers and endpoint event with session ID: #{session_id}")

     # Keep socket open to receive InitializeResult event later
     # :gen_tcp.close(socket)

     # Now test the RPC endpoint with a simple initialize request (while SSE socket is open)
     # Create a Finch pool for our test
     finch_name = :test_finch_rpc
     start_supervised!({Finch, name: finch_name})

     # Build and send a simple initialize request
     url = "http://localhost:#{port}#{session_path}"
     init_body = Jason.encode!(%{
       "jsonrpc" => "2.0",
       "method" => "initialize",
       "params" => %{
         "protocolVersion" => "2024-11-05",
         "clientInfo" => %{"name" => "TestClient", "version" => "0.1"}
       },
       "id" => 1
     })

     request = Finch.build(:post, url,
       [{"content-type", "application/json"}],
       init_body
     )

     # Send request and verify we get a 204 response (acknowledgement)
     {:ok, response} = Finch.request(request, finch_name)
     assert response.status == 204,
       "Expected 204 No Content response for initialize POST, got #{response.status}"

     Logger.info("Successfully sent initialize POST and received 204 ack.")

     # Now, receive the InitializeResult event from the original SSE socket
     # Increase timeout slightly as result processing might take a moment
     {:ok, raw_result_data} = :gen_tcp.recv(socket, 0, 2000)

     Logger.debug("Received raw data on SSE socket after initialize POST: #{inspect(raw_result_data)}")

     # --- Robust SSE Event Parsing ---
     # 1. Strip potential chunk metadata (hex length + \r\n)
     sse_content = Regex.replace(~r/^[0-9A-Fa-f]+\r\n/, raw_result_data, "") |> String.trim()

     # 2. Split into lines and find event and data
     lines = String.split(sse_content, "\n", trim: true)
     event_line = Enum.find(lines, &String.starts_with?(&1, "event:"))
     data_line = Enum.find(lines, &String.starts_with?(&1, "data:"))

     # 3. Assert event type
     assert event_line == "event: message", "Expected 'event: message', got: #{inspect(event_line)}"

     # 4. Extract and decode JSON data
     assert data_line != nil, "Missing 'data:' line in SSE event"
     json_string = String.replace_prefix(data_line, "data: ", "")

     decoded_data =
       try do
         Jason.decode!(json_string)
       rescue
         e in Jason.DecodeError ->
           flunk("Failed to decode JSON data received via SSE: #{inspect(e)}\nJSON String: #{json_string}")
       end

     Logger.debug("Decoded SSE data: #{inspect(decoded_data)}")

     # 5. Assert on the decoded map structure
     assert decoded_data["jsonrpc"] == "2.0"
     assert decoded_data["id"] == 1
     assert is_map(decoded_data["result"]), "Missing 'result' map in decoded data"
     assert decoded_data["result"]["protocolVersion"] == "2024-11-05", "Incorrect protocolVersion in result"
     assert decoded_data["result"]["serverInfo"]["name"] == "GraphOS Server", "Incorrect server name in result" # Updated expected name
     assert decoded_data["result"]["capabilities"]["supportedVersions"] == ["2024-11-05"], "Incorrect supportedVersions in result"

     Logger.info("Successfully received and validated InitializeResult event via SSE stream.")

     # Clean up the socket now
     :gen_tcp.close(socket)
   end
end
