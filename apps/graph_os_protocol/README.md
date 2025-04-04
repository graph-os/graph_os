# GraphOS.Protocol

Protocol interfaces for GraphOS, including HTTP, JSON-RPC, gRPC, and more.

## Key Features

- HTTP/REST API interfaces
- JSON-RPC implementation
- gRPC implementation
- Server-Sent Events (SSE)
- WebSockets
- Routing and controllers
- Secret-based authentication

## Starting the Protocol Server

You can start the protocol server using the mix task:

```bash
# Start directly (default behavior)
mix protocol.server

# Start in a tmux session
mix protocol.server start

# Start and immediately join the tmux session
mix protocol.server start_and_join

# Run without tmux (same as the default)
mix protocol.server direct
```

The server starts the following adapters by default:
- JSON-RPC adapter (registered as `GraphOS.Protocol.JSONRPCAdapter`)
- gRPC adapter (registered as `GraphOS.Protocol.GRPCAdapter`)

## Manual Usage

To manually start the protocol adapters in your application:

```elixir
# Start the application
Application.ensure_all_started(:graph_os_protocol)

# Start a JSON-RPC adapter
{:ok, jsonrpc_pid} = GraphOS.Protocol.JSONRPC.start_link(
  name: JSONRPCAdapter,
  plugs: [
    {AuthPlug, realm: "api"}, 
    LoggingPlug
  ]
)

# Process a JSON-RPC request
request = %{
  "jsonrpc" => "2.0",
  "id" => 1,
  "method" => "graph.query.nodes.list",
  "params" => %{
    "filters" => %{
      "type" => "person"
    }
  }
}

{:ok, response} = GraphOS.Protocol.JSONRPC.process(JSONRPCAdapter, request)
```

## Authentication

GraphOS Protocol interfaces use a secret-based authentication system to secure the endpoints:

- **Secret Configuration**: Set the `GRAPH_OS_RPC_SECRET` environment variable or configure in your config files:
  ```elixir
  # In config/dev.exs or config/runtime.exs
  config :graph_os_protocol, :auth,
    rpc_secret: "your_secret_here",
    required: true  # Set to false to disable authentication
  ```

- **Client Authentication**: When making requests to GraphOS, include the secret:
  ```
  # HTTP/JSON-RPC request headers
  X-GraphOS-RPC-Secret: your_secret_here
  
  # Or with Bearer format
  Authorization: Bearer your_secret_here
  
  # gRPC metadata
  x-graph-os-rpc-secret: your_secret_here
  ```

- **Security Notes**:
  - For enhanced security on local-only services, consider using Unix sockets
  - The secret comparison uses constant-time algorithms to prevent timing attacks
  - In development mode, authentication can be disabled by setting `required: false`

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