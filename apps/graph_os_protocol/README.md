# GraphOS.Protocol

Protocol interfaces for GraphOS, including HTTP, JSON-RPC, gRPC, and more.

## Key Features

- HTTP/REST API interfaces
- JSON-RPC implementation
- gRPC implementation
- Server-Sent Events (SSE)
- WebSockets
- Routing and controllers

## Documentation

For detailed documentation, please refer to the centralized documentation:

- [CLAUDE.md](../../instructions/CLAUDE.md) - Development guide with component details
- [BOUNDARIES.md](../../instructions/BOUNDARIES.md) - Component boundaries and API definitions

## Local Development

```bash
# Run tests
mix test

# Format code
mix format
```

## Installation

```elixir
def deps do
  [
    {:graph_os_protocol, "~> 0.1.0"}
  ]
end
```