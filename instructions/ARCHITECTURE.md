# GraphOS Architecture

## Overview

GraphOS is an umbrella Elixir project designed to provide a unified interface for interacting with code as a graph, enabling AI agents to understand, navigate, and execute operations on code.

The architecture follows these core principles:
1. **Graph as the primary abstraction**
2. **Component execution through standardized protocols**
3. **Integration with AI through MCP (Model Context Protocol)**
4. **Strict dependency hierarchy**
5. **Secure access control through graph-based permissions**

## Dependency Hierarchy

Applications follow a strict dependency ordering to maintain modularity and prevent circular dependencies:

1. **tmux** - Development tooling foundation
2. **mcp** - Model Context Protocol library
3. **graph_os_graph** - Graph data structure
4. **graph_os_core** - Core system functionality
5. **graph_os_dev** - Development interface

Applications can only depend on those earlier in this list, not later. For example, `mcp` cannot depend on `graph_os_graph`, but `graph_os_graph` can depend on `mcp`.

## Component Structure

### Core Libraries

1. **tmux** - Development tools for managing multiple processes
   - No dependencies on other GraphOS components
   - Provides foundation for development workflows

2. **mcp** - Model Context Protocol implementation
   - JSON-RPC based protocol for AI agents to interact with tools
   - Handles server/client communication
   - Provides transport layers (STDIO, HTTP, SSE)
   - No dependencies on other GraphOS components

3. **graph_os_graph** - The foundational graph data structure
   - Provides generic graph operations (nodes, edges, traversal)
   - Implements storage backends (currently ETS)
   - Defines core graph protocols
   - May depend on: `mcp`

4. **graph_os_core** - Core functionality
   - Builds code graphs from source code
   - Provides file system monitoring
   - Implements code parsing and analysis
   - Connects graph components to executable resources
   - May depend on: `mcp`, `graph_os_graph`

5. **graph_os_dev** - Development interface
   - Web dashboard for graph visualization
   - Interactive code exploration
   - Live development environment
   - May depend on: `mcp`, `graph_os_graph`, `graph_os_core`

### Extension System

GraphOS supports two types of extension modules:

1. **GraphOS.Core** - Core "OS" applications
   - Built-in interface bindings (filesystem, git, etc.)
   - System-level functionality
   - Tightly integrated with the core system
   - Part of graph_os_core application

2. **GraphOS.Modules** - Optional/installable modules
   - Extension functionality
   - Dynamically loadable at runtime
   - Isolated from core system
   - Follow the same dependency rules

## Execution Architecture

### 1. Executable Graph Nodes

Any graph node can be made executable by implementing the `GraphOS.Executable` protocol:

```elixir
defprotocol GraphOS.Executable do
  @doc "Execute the node with the given context"
  @spec execute(t(), map(), access_context()) :: {:ok, any()} | {:error, term()}
  def execute(node, context \\ %{}, access_context \\ nil)
end
```

Nodes can then be executed through the Graph API:

```elixir
# Execute a node by ID
GraphOS.Graph.execute_node(node_id, context, access_context)

# Execute a node directly
GraphOS.Graph.execute(node, context, access_context)
```

### 2. MCP Integration

Components are exposed to AI agents through MCP using a declarative approach:

1. **MCP Resource** - A node or collection of nodes exposed as a resource
   ```elixir
   use MCP.Resource, type: :graph
   ```

2. **MCP Tool** - Operations that can be performed on nodes
   ```elixir
   use MCP.Tool
   ```

3. **MCP Server** - Server that hosts MCP resources and tools
   ```elixir
   use MCP.Server, resources: [MyGraphResource], tools: [MyGraphTool]
   ```

### 3. Component Registration

Core components register themselves through hooks:

```elixir
defmodule MyComponent do
  use GraphOS.Component

  # Register resources
  resource "filesystem", type: :filesystem do
    # Resource definition
  end

  # Register tools
  tool "filesystem.read", description: "Read a file" do
    # Tool implementation
  end
end
```

## Access Control Model

GraphOS implements a graph-based access control model with the following components:

### 1. Actor-Scope Model

- **Actors**: Represented as nodes in the graph
  - Users, services, AI agents, or any entity performing operations
  - Have identity and attribute properties

- **Scopes**: Represented as edges in the graph
  - Connect actors to resource types or specific resources
  - Define permitted operations (e.g., read, write, execute)
  - Can include constraints or conditions

- **Resources**: Target nodes that actors act upon
  - Any node in the graph that can be accessed or manipulated
  - Organized by type hierarchies for permission inheritance

```elixir
# Access control is defined within the graph itself
GraphOS.AccessControl.define_actor("user:alice")
GraphOS.AccessControl.grant_permission("user:alice", "filesystem", [:read, :write])
```

### 2. Secure Implementation

The access control system is implemented with these security principles:

- **Reference Monitor**: All access requests pass through a central validation component
- **Complete Mediation**: Every operation is checked against the access control policy
- **Tamper Resistance**: Access control nodes and edges have special protection
- **Verifiable**: Access decisions can be audited and verified
- **Fail-Closed**: Operations fail by default if permissions are not explicitly granted

### 3. Multiple Graph Support

Each graph instance maintains its own access control subgraph:

```elixir
# Initialize a graph with access control
GraphOS.Graph.init(name: "code_graph", access_control: true)

# Access control is scoped to this specific graph
GraphOS.Graph.grant_permission("code_graph", "user:alice", "filesystem", [:read])
```

## Interface Consolidation

To avoid duplication across Graph, MCP, and host interface APIs:

1. **Primary API**: GraphOS.Graph is the primary API
2. **Protocol Adapters**: MCP automatically maps to Graph operations
3. **Interface Bindings**: 
   - **GraphOS.Core**: Core system interfaces (filesystem, git, network)
   - **GraphOS.Modules**: Extension interfaces (databases, cloud services, etc.)

Both Core and Module interfaces implement the same protocols, providing a consistent interface regardless of where the functionality is defined.

## Data Flow

1. **Graph Building**:
   - Source code is parsed and analyzed
   - Graph nodes and edges are created
   - Relationships between code elements are established

2. **Graph Exploration**:
   - AI agents query the graph using MCP tools
   - Graph nodes and relationships are traversed
   - Results are returned in a standardized format

3. **Node Execution**:
   - AI agents select nodes to execute
   - Access control verification is performed
   - Execution is performed through the GraphOS.Executable protocol
   - Results are returned to the agent

## Scalability Considerations

The architecture supports:
1. **Distribution**: Node execution can be distributed across multiple Elixir nodes
2. **Persistence**: Graph data can be persisted to disk or database
3. **Streaming**: Operations support streaming for large datasets

## Security Best Practices

1. **Principle of Least Privilege**: Actors are granted only the permissions they need
2. **Defense in Depth**: Multiple layers of security controls
3. **Isolation**: Operations are isolated through Elixir process boundaries
4. **Immutable Audit Trail**: All operations are logged to an append-only store

## Extension Mechanisms

1. **Custom Nodes**: Define custom node types with specialized execution behavior
2. **Protocol Extensions**: Extend existing protocols with new capabilities
3. **Integration Points**: Connect to external systems through adapters
4. **Module System**: Dynamically loadable extension modules