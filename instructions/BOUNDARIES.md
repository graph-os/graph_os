# GraphOS Component Boundaries

This document defines the boundaries and responsibilities of each component in the GraphOS architecture.

## Overall Architecture

GraphOS is designed as a collection of focused applications, each with a specific responsibility:

1. **tmux**: Development tooling with mix tasks
2. **mcp**: Messaging and communication protocol
3. **graph_os_graph**: Pure graph data structure library
4. **graph_os_core**: Core GraphOS functionality and infrastructure
5. **graph_os_protocol**: Protocol interfaces (HTTP, JSON-RPC, gRPC, SSE)
6. **graph_os_dev**: Development tools and interfaces
7. **graph_os_cli**: Terminal UI client (Rust)

## Component Dependencies

The dependency flow is strictly downward:

```
tmux
  ↓
mcp
  ↓
graph_os_graph
  ↓
graph_os_core
  ↓
graph_os_protocol
  ↓     ↙
graph_os_dev  graph_os_cli
```

## Component Responsibilities

### graph_os_graph

A pure graph data structure library with no dependencies on other GraphOS components except potentially MCP for serialization.

#### Key Boundary Rules
- GraphOS.Graph is a pure graph data structure library
- It defines interfaces but not implementations for cross-cutting concerns
- No application infrastructure, execution logic or business logic belongs here
- Protocol adapters have been moved to GraphOS.Protocol
- Node execution logic has been moved to GraphOS.Core

#### Dependencies
- `mcp` - For serialization (limited usage)

#### Public API
- `GraphOS.Graph` - Main module for graph operations
- `GraphOS.Graph.Node` - Node representation
- `GraphOS.Graph.Edge` - Edge representation
- `GraphOS.Graph.Meta` - Metadata for graph elements
- `GraphOS.Graph.Transaction` - Transaction handling
- `GraphOS.Graph.Operation` - Individual operations
- `GraphOS.Graph.Query` - Query interface
- `GraphOS.Graph.Store` - Storage interface
- `GraphOS.Graph.Algorithm` - Graph algorithms
- `GraphOS.Graph.Access` - Access control interface
- `GraphOS.Graph.Subscription` - Subscription interface (minimal implementation)
- `GraphOS.Graph.Protocol` - Core protocol definition
- `GraphOS.Graph.Schema` - Schema definitions for graph elements
- `GraphOS.Graph.SchemaBehaviour` - Schema behavior interface
- `GraphOS.Graph.Schema.Adapter` - Utilities for schema protocol adapters

#### Responsibilities
- Graph data structures (nodes, edges)
- Graph operations and transactions
- Query interface for graph traversal
- Storage implementations (ETS, etc.)
- Graph algorithms (path finding, traversal, etc.)
- Type/schema definitions for graph elements
- Access control interface definitions

### graph_os_core

Core GraphOS functionality and infrastructure.

#### Dependencies
- `tmux` - For development workflow tools
- `mcp` - For protocol communication
- `graph_os_graph` - For graph data structures and operations

#### Public API
- `GraphOS.Core` - Main module for core operations
- `GraphOS.Core.Application` - Application lifecycle
- `GraphOS.Core.Supervisor` - Supervision tree
- `GraphOS.Core.AccessControl` - Access control system
- `GraphOS.Core.CodeGraph` - Code graph management
- `GraphOS.Core.FileWatcher` - File monitoring
- `GraphOS.Core.GitIntegration` - Git integration
- `GraphOS.Core.Adapter` - Adapter system
- `GraphOS.Component` - Component system
- `GraphOS.Component.{Builder, Context, Pipeline, Registry}` - Component subsystems

#### Internal Modules
- `GraphOS.Core.CodeGraph.*` - Code analysis and graph generation
- `GraphOS.Core.Executable.*` - Executable management
- `GraphOS.Core.MCP.*` - MCP server implementations

#### Responsibilities
- Application lifecycle management
- Component registry and discovery
- Access control implementation
- Integration with external systems
- Executable graph management
- File watching and monitoring
- Git integration
- Pipeline implementations
- Adapter implementations for various interfaces

### graph_os_protocol

Protocol interfaces for GraphOS.

#### Dependencies
- `mcp` - For communication protocol
- `graph_os_graph` - For graph data structures
- `graph_os_core` - For core functionality

#### Public API
- `GraphOS.Protocol` - Main module for protocol operations
- `GraphOS.Protocol.HTTP` - HTTP interface
- `GraphOS.Protocol.JsonRpc` - JSON-RPC implementation
- `GraphOS.Protocol.GRPC` - gRPC implementation
- `GraphOS.Protocol.SSE` - SSE implementation
- `GraphOS.Protocol.Router` - Routing logic
- `GraphOS.Protocol.Controllers.*` - HTTP controllers

#### Responsibilities
- HTTP/REST API interfaces
- JSON-RPC implementation
- gRPC implementation
- Server-Sent Events (SSE)
- WebSockets
- Routing and controllers
- Standard Plug implementation

### graph_os_dev

Development tools and interfaces.

#### Dependencies
- `mcp` - For communication protocol
- `graph_os_graph` - For graph data structures
- `graph_os_core` - For core functionality
- `graph_os_protocol` - For protocol interfaces

#### Public API
- `GraphOS.Dev` - Main module for development tools
- `GraphOS.Dev.Server` - Development server
- `GraphOS.Dev.Web` - Web interface

#### Responsibilities
- Development server
- Web UI for graph visualization
- Interactive development tools
- Debugging utilities

### graph_os_cli

Terminal UI client interface.

#### Dependencies
- `mcp` - For communication protocol
- `graph_os_graph` - For graph data structures
- `graph_os_core` - For core functionality
- `graph_os_protocol` - For protocol interfaces (gRPC)

#### Public API
- Command-line interface
- Terminal UI views

#### Responsibilities
- Terminal UI for interacting with GraphOS
- Command-line operations
- Interactive terminal-based graph exploration
- Local workflow management

### mcp

Messaging and communication protocol.

#### Dependencies
None (standalone library)

#### Public API
- `MCP` - Main module for messaging
- `MCP.Client` - Client implementation
- `MCP.Server` - Server implementation
- `MCP.Message` - Message format

#### Responsibilities
- Protocol definition
- Message format
- Transport mechanisms

### tmux

Development tooling.

#### Dependencies
None (standalone library)

#### Public API
- `Tmux` - Main module for tmux utilities
- `Mix.Tasks.*` - Mix tasks

#### Responsibilities
- Development workflow utilities
- Mix tasks

## Cross-Component Communication

- **graph_os_dev** → **graph_os_protocol** → **graph_os_core**: UI uses Protocol interfaces which use Core functionality
- **graph_os_cli** → **graph_os_protocol** → **graph_os_core**: CLI uses Protocol interfaces which use Core functionality
- **graph_os_core** → **graph_os_graph**: Core uses Graph for data storage and queries
- **graph_os_graph** → **mcp**: Graph can use MCP for serialization
- All components may use **tmux** for development tooling

## Breaking Boundary Changes

Any change that affects the public API of a component must:
1. Be documented in the component's CHANGELOG.md
2. Be reflected in this BOUNDARIES.md file
3. Update the component's README.md file
4. Include appropriate version changes following semantic versioning

## Enforcing Boundaries

Boundaries are enforced through:
1. Mix dependencies in each application's mix.exs
2. Runtime checks for proper API usage
3. Comprehensive test coverage at boundaries