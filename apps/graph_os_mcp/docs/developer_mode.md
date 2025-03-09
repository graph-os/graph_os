# GraphOS Development Mode

This document describes the development environment for the GraphOS project, which provides a more interactive development experience.

## Features

- **Live Code Reloading**: Changes to Elixir files are automatically recompiled and reloaded
- **MCP Endpoint**: Provides access to the CodeGraph functionality through the MCP protocol
- **Graph Viewer**: An interactive viewer for graph content of files and modules
- **Event System**: Real-time updates using Server-Sent Events (SSE)

## Starting the Development Server

To start the development server, run:

```bash
cd graph_os
mix mcp.dev
```

This will start the server on `http://127.0.0.1:4000` by default.

### Options

- `--port` or `-p`: Specify the port to run on (default: 4000)
- `--host` or `-h`: Specify the host to bind to (default: 127.0.0.1)
- `--no-halt`: Do not halt the Erlang VM after starting the server (useful for IEx sessions)

Examples:

```bash
# Start on port 5000
mix mcp.dev --port 5000

# Bind to all interfaces
mix mcp.dev --host 0.0.0.0

# Start in IEx with the server running
iex -S mix mcp.dev
```

## Using the Development UI

The development UI is available at `http://localhost:4000/dev` (or whatever host/port you configured).

### Features

1. **Server Status**: Shows the connection status and last reload time
2. **Graph Viewer**: View the graph content of files or modules:
   - File path: Enter a relative path to a file in the project
   - Module name: Enter the full module name (e.g., `GraphOS.Graph.Query`)
3. **Event Log**: Shows real-time updates and server events

## API Endpoints

The development server provides the following API endpoints:

### MCP Endpoints

- `GET /mcp/sse`: Server-Sent Events endpoint for real-time updates
- `POST /mcp/message`: MCP protocol message endpoint
- `GET /mcp/health`: Health check endpoint

### Graph Endpoints

- `GET /graph/file?path=PATH`: Get graph data for a specific file
- `GET /graph/module?name=MODULE`: Get graph data for a specific module

## Development Tips

1. **Live Reloading**: The development server automatically recompiles and reloads code changes. You'll see these changes in the Event Log.

2. **Inspecting Graph Data**: Use the Graph Viewer to inspect how your code is represented in the graph. This is useful for understanding code relationships.

3. **Debug with IEx**: Start the server with `iex -S mix mcp.dev` to have access to the interactive shell for debugging.

## Troubleshooting

- If the server fails to start, check for port conflicts (another process might be using the port)
- If code changes aren't reflecting, check the Event Log for compilation errors
- If the graph data isn't loading, verify that the file path or module name is correct

## Implementation Details

The development server works by:

1. Starting a file watcher on the project's apps directory
2. Monitoring for file changes and automatically recompiling them
3. Broadcasting events to connected clients using Server-Sent Events (SSE)
4. Providing a web interface for interacting with the graph data

This approach allows for a more seamless development experience without requiring manual recompilation or server restarts. 