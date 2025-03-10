# GraphOS MCP Debugging Tools

This document describes the debugging tools available for the GraphOS MCP server.

## Starting the MCP Server

The MCP server can be started in three different modes, each with increasing levels of functionality:

### 1. SSE-only Mode

This mode only exposes the SSE connection endpoint, which is useful for minimal footprint:

```bash
mix mcp.sse [--port PORT]
```

### 2. Debug Mode

This mode exposes the SSE connection endpoint plus JSON/API debugging endpoints (no HTML/JS interfaces):

```bash
mix mcp.debug [--port PORT]
```

### 3. Inspect Mode

This mode exposes all endpoints, including the full HTML/JS inspector interface:

```bash
mix mcp.inspect [--port PORT]
```

## Available Endpoints

Depending on the mode, the following endpoints are available:

### Basic Endpoints (all modes)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sse` | GET | Establishes a Server-Sent Events (SSE) connection to the MCP server |

### Debug Endpoints (debug and inspect modes)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/rpc` | POST | Sends a JSON-RPC request to the MCP server (requires session_id query parameter) |
| `/rpc/:session_id` | POST | Sends a JSON-RPC request to the MCP server for a specific session |
| `/debug/:session_id` | GET | Returns debugging information about a specific session |
| `/debug/sessions` | GET | Lists all active sessions |
| `/debug/api` | GET | Returns an API description |

### Inspector Endpoints (inspect mode only)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/inspector` | GET | Provides a web interface for inspecting and debugging MCP protocol messages |
| `/debug/tool/:tool_name` | GET | Provides a web interface for testing a specific tool |

## MCP Inspector

The MCP Inspector is an integrated tool for inspecting and debugging MCP protocol messages. It provides a graphical interface for viewing and analyzing MCP traffic.

### Using the Inspector

1. Start the MCP server in inspect mode: `mix mcp.inspect`
2. Navigate to `/inspector` in your browser.
3. Click "Load Inspector" to initialize the inspector interface.
4. The inspector will automatically connect to your MCP server's SSE endpoint.
5. You can change the SSE endpoint URL if needed (e.g., for remote debugging).

## Debugging Workflow

A typical debugging workflow might look like:

1. Start the MCP server in inspect mode: `mix mcp.inspect`
2. Open the MCP Inspector at `/inspector`.
3. Test specific tools using the Tool Debug UI:
   - Navigate to `/debug/tool/<tool_name>`
   - Connect to a session
   - Send test requests
4. View the results in both the Debug UI and the MCP Inspector.

## Troubleshooting

- If you encounter connection issues, check that your MCP server is running.
- If tool invocations fail, check the server logs for error messages.
- Use the session debug endpoint (`/debug/:session_id`) to inspect the session state.
- If the inspector fails to load, check your browser's console for errors. 