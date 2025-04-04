# MCP Connection Debugging Report (Elixir Server vs. Cline Client)

## Problem

The Cline VS Code extension (acting as an MCP client) successfully initiates an SSE connection to the local Elixir MCP server (`graph_os_protocol`), but gets stuck displaying "Restarting..." or "Connecting..." and never shows the available tools. Server logs indicate the `initialize` handshake completes successfully, but subsequent requests like `tools/list` are never received from the client.

## Investigation Summary

We performed extensive debugging on both the server and client sides (using reference code).

**Server-Side (Elixir - `mcp` & `graph_os_protocol`):**

1.  **Protocol Version:** Confirmed the server uses MCP protocol version `2024-11-05` (defined in `mcp/lib/mcp/message.ex`).
2.  **Transport:** Uses Bandit adapter with default settings (HTTP/1.1) on `http://localhost:4000`. Explicitly binding to `127.0.0.1` vs `0.0.0.0` made no difference to the core issue. HTTP/2 is not required for SSE.
3.  **SSE Handshake:**
    *   Correctly handles the initial `GET /` request from the client.
    *   Establishes the SSE stream (`text/event-stream`, `keep-alive`).
    *   Generates a session ID and registers the connection process.
    *   **Crucially, sends the `endpoint` event back to the client immediately after connection** (`event: endpoint\ndata: /?sessionId=...\n\n`). This was identified as a missing step and fixed.
4.  **Initialize Request Handling:**
    *   Correctly receives the `POST /?sessionId=...` request for the `initialize` method.
    *   Parses the request body using `Plug.Parsers`.
    *   Calls the `GraphOS.Protocol.MCPImplementation.handle_initialize` callback (which uses the default `MCP.Server` implementation).
    *   Updates the session state in the `ConnectionRegistry` to mark it as `initialized: true`.
    *   Sends a successful `InitializeResult` back to the client with a 200 OK status, echoing the request ID (tested with both `0` and a fixed `999`). The response includes the correct protocol version and server info.
5.  **`initialized` Notification Handling:** The server uses the default notification handler from `MCP.Server`, which correctly ignores the `notifications/initialized` message sent by the client after successful initialization (this notification was confirmed to be received in server logs during earlier debugging steps before logs were removed).
6.  **`tools/list` Handler:** The `handle_list_tools` implementation was corrected to remove the non-standard `outputSchema` key, ensuring the response strictly adheres to the expected schema.
7.  **Debugging Steps:** Added extensive logging, tested different response IDs, added artificial delays – none resolved the client-side issue.

**Client-Side (Cline Extension / TypeScript SDK - via `reference/` code):**

1.  **Protocol Version:** The reference TypeScript SDK (`reference/typescript-sdk/src/types.ts`) also targets `2024-11-05` as the latest version.
2.  **Connection Flow (`McpHub.ts` & SDK):**
    *   `McpHub.ts` creates an `SSEClientTransport` and a `Client`.
    *   It calls `await client.connect(transport)`.
    *   The SDK's `Client.connect` method first establishes the transport connection (GET request, waits for `endpoint` event) and *then* sends the `initialize` request using `client.request()`.
    *   After `client.connect()` resolves, `McpHub.ts` calls `fetchToolsList()`, which uses `client.request({ method: "tools/list" }, ...)`.
3.  **Observed Behavior:**
    *   The client successfully performs the initial GET and sends the `initialize` POST.
    *   The client *receives* the successful `InitializeResult` from the server (implied, as the server logs sending it and no network errors occur at this stage).
    *   The client then **times out** during the `client.connect()` process, logging `McpError: MCP error -32001: Request timed out`.
    *   The `client.connect()` promise rejects due to the timeout.
    *   As a result, `McpHub.ts` never reaches the `fetchToolsList()` call.
4.  **Timeout Error:**
    *   The error code `-32001` corresponds to `ErrorCode.RequestTimeout` as defined in the reference TypeScript SDK (`src/types.ts`).
    *   The error message "Request timed out" also matches the SDK's timeout error.
    *   The timeout occurs despite the server responding quickly to the `initialize` request.
5.  **Test Script:** A standalone Node.js test script using the SDK showed initial connectivity issues (`ECONNREFUSED`) likely due to server binding, but after fixing that, it also appeared to hang during the `client.connect()` phase, similar to the Cline extension.

## Conclusion

The Elixir server implementation appears to correctly follow the MCP specification for the SSE transport and initialization handshake. It successfully receives the `initialize` request and sends a valid success response.

The issue lies on the **client side**, specifically within the TypeScript SDK's `Client.connect` method or its interaction with the `SSEClientTransport`. The client times out *after* the server has successfully responded to the `initialize` request. This likely happens either:

1.  During the client's internal processing of the received `InitializeResult`.
2.  During the client's attempt to send the subsequent `notifications/initialized` message back to the server.

A subtle bug, race condition, or unexpected blocking behavior within the client SDK or the Cline extension's usage of it seems to be preventing the `connect` method from resolving successfully, thus preventing the subsequent `tools/list` request and causing the UI to remain stuck. Further investigation requires debugging the client-side TypeScript code.
