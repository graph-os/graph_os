# GraphOS.Store Algorithms

This directory contains implementations of various graph algorithms that can be used to traverse and analyze graphs stored in GraphOS.Store.

## Available Algorithms

### 1. Breadth-First Search (BFS)

BFS traverses a graph starting from a specified node, exploring all neighboring nodes at the current depth before moving to nodes at the next depth level.

```elixir
# Using the Algorithm module directly
{:ok, nodes} = GraphOS.Store.Algorithm.bfs("node1", max_depth: 3)

# Using Store.traverse
{:ok, nodes} = GraphOS.Store.traverse(:bfs, {"node1", [max_depth: 3]})
```

BFS supports the following options:
- `:max_depth` - Maximum depth to traverse (default: 10)
- `:direction` - Direction to traverse (:outgoing, :incoming, or :both) (default: :outgoing)
- `:edge_type` - Optional filter for specific edge types

### 2. Shortest Path (Dijkstra's Algorithm)

Finds the shortest path between two nodes in the graph using Dijkstra's algorithm.

```elixir
# Using the Algorithm module directly
{:ok, path, weight} = GraphOS.Store.Algorithm.shortest_path("node1", "node5", weight_property: "distance")

# Using Store.traverse
{:ok, path, weight} = GraphOS.Store.traverse(:shortest_path, {"node1", "node5", [weight_property: "distance"]})
```

### 3. Connected Components

Identifies all connected components in the graph (groups of nodes that are connected to each other but disconnected from other groups).

```elixir
# Using the Algorithm module directly
{:ok, components} = GraphOS.Store.Algorithm.connected_components()

# Using Store.traverse
{:ok, components} = GraphOS.Store.traverse(:connected_components, [])
```

### 4. PageRank

Calculates PageRank scores for all nodes in the graph, which measures the importance of each node.

```elixir
# Using the Algorithm module directly
{:ok, scores} = GraphOS.Store.Algorithm.page_rank(iterations: 20, damping: 0.85)

# Using Store.traverse
{:ok, scores} = GraphOS.Store.traverse(:page_rank, [iterations: 20, damping: 0.85])
```

### 5. Minimum Spanning Tree (MST)

Finds the minimum spanning tree of the graph using Kruskal's algorithm, which connects all nodes with the minimum possible total edge weight.

```elixir
# Using the Algorithm module directly
{:ok, edges, total_weight} = GraphOS.Store.Algorithm.minimum_spanning_tree(weight_property: "distance")

# Using Store.traverse
{:ok, edges, total_weight} = GraphOS.Store.traverse(:minimum_spanning_tree, [weight_property: "distance"])
```

## Common Options

Most algorithms support the following options:

- `:edge_type` - Filter edges by type
- `:direction` - Direction of traversal (`:outgoing`, `:incoming`, or `:both`)
- `:weight_property` - Property name to use for edge weights (default: "weight")
- `:default_weight` - Default weight to use when a property is not found (default: 1.0)
- `:prefer_lower_weights` - Whether lower weights are preferred (default: true)

Refer to each algorithm's documentation for algorithm-specific options. 