# GraphOS.Graph

The core graph library for GraphOS, providing data structures, algorithms, and storage capabilities.

## Features

* Graph data structures (nodes, edges with properties)
* Graph algorithms (centrality metrics, path finding, etc.)
* ETS-based in-memory storage
* Optional persistent storage integration

## Installation

Add to your mix.exs dependencies:

```elixir
def deps do
  [
    {:graph_os_graph, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Create a new graph
graph = GraphOS.Graph.new()

# Add nodes
graph = GraphOS.Graph.add_node(graph, "node1", %{label: "Person"})
graph = GraphOS.Graph.add_node(graph, "node2", %{label: "Person"})

# Add an edge
graph = GraphOS.Graph.add_edge(graph, "node1", "node2", :knows, %{since: ~D[2023-01-01]})

# Query the graph
neighbors = GraphOS.Graph.neighbors(graph, "node1")
```

## Documentation

Generate documentation with:

```bash
mix docs
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/graph_os_graph>.

