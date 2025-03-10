# MCP Mix Tasks

This directory contains Mix tasks for the Model Context Protocol (MCP) component of GraphOS.

## Server Management

- `mcp.server`: Manage the MCP server in tmux
  - `start`: Start the server in a tmux session
  - `stop`: Stop the running server
  - `restart`: Restart the server
  - `status`: Check if the server is running
  - `join`: Join the tmux session of a running server
  - `start_and_join`: Start the server and immediately join the session

- `mcp.start`: **DEPRECATED** - Simple alias for `mix mcp.server start_and_join`
  - Use `mix mcp.server start_and_join` instead

## Testing Tasks

- `mcp.test_types`: Test type parity between Elixir and TypeScript
- `mcp.test_client`: Test MCP client functionality without requiring a server
- `mcp.test_server`: Test the Bandit server configuration
- `mcp.test_endpoint`: Test MCP.Endpoint functionality

## Debugging Tasks

- `mcp.debug`: Debug MCP functionality
- `mcp.inspect`: Inspect MCP objects and their structure
- `mcp.sse`: Test the MCP SSE (Server-Sent Events) endpoint

## Usage Examples

Start the MCP server:
```
mix mcp.server start
```

Join an existing MCP server session:
```
mix mcp.server join
```

Start the server and join in one command:
```
mix mcp.server start_and_join
```

Run type parity tests:
```
mix mcp.test_types
```

Debug MCP functionality:
```
mix mcp.debug
``` 