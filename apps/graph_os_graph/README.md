# GraphOS.GraphContext

The core graph library for GraphOS, providing data structures, algorithms, and storage capabilities. This is a pure graph library with no dependencies on other GraphOS components except potentially MCP for serialization.

## Features

* Graph data structures (nodes, edges with properties)
* Graph algorithms (centrality metrics, path finding, etc.)
* ETS-based in-memory storage
* Optional persistent storage integration
* Query interface for graph traversal
* Transaction and operation system

## Documentation

For detailed documentation, please refer to the centralized documentation:

- [CLAUDE.md](../../instructions/CLAUDE.md) - Development guide with component details
- [BOUNDARIES.md](../../instructions/BOUNDARIES.md) - Component boundaries and API definitions

## Usage

```elixir
# Create a new graph
graph = GraphOS.GraphContext.new()

# Add nodes
graph = GraphOS.GraphContext.add_node(graph, "node1", %{label: "Person"})
graph = GraphOS.GraphContext.add_node(graph, "node2", %{label: "Person"})

# Add an edge
graph = GraphOS.GraphContext.add_edge(graph, "node1", "node2", :knows, %{since: ~D[2023-01-01]})

# Query the graph
neighbors = GraphOS.GraphContext.neighbors(graph, "node1")
```

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
    {:graph_os_graph, "~> 0.1.0"}
  ]
end
```