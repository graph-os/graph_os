# GraphOS.Store

GraphOS.Store is the primary Elixir interface for creating, managing, and interacting with graph data within the GraphOS ecosystem. It provides a flexible API for storing and retrieving graph entities (nodes, edges) using different storage engines.

## Project status
- [PLAN.md](PLAN.md)
- [PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md)
- [TESTING.md](TESTING.md)

## Overview

GraphOS.Store offers a minimal yet powerful interface for graph data management. The default implementation uses ETS for high-performance in-memory storage, but the architecture allows for alternative storage adapters (e.g., persistent databases) in the future. It emphasizes schema validation, custom types, access control, and includes a suite of graph algorithms.

**Key Concepts:**

*   **Store:** An isolated container for graph data, managed by a GenServer process. Multiple stores can exist concurrently.
*   **Adapter:** The underlying storage engine (e.g., `GraphOS.Store.Adapter.ETS`).
*   **Entities:** Nodes and Edges, defined with optional schemas.
*   **Algorithms:** Functions for graph analysis (BFS, Shortest Path, etc.).
*   **Access Control:** Mechanisms for managing permissions (Policies, Actors, Groups).

## Features

*   Simple API for CRUD (Create, Read, Update, Delete) operations on nodes and edges.
*   Support for **multiple, named stores** within the same application for data isolation.
*   Schema-based data validation for nodes and edges.
*   Support for defining custom node and edge types with specific behaviours.
*   Subscription system for real-time updates on graph changes.
*   Integrated access control and permission management.
*   Built-in graph algorithms (BFS, Shortest Path, PageRank, MST, Connected Components).
*   Performance optimizations for large graphs (indexing, caching, concurrency).

## Development Status & Planning

*   **Tests:** See `mix test` output for current status.
*   **Coverage:** Run `mix coveralls.html` for a detailed report.
*   **Code Quality:** Run `mix credo` for analysis.
*   **Roadmap & Tasks:** See [PLAN.md](PLAN.md) for the development plan and [TASKS.md](TASKS.md) for module testing status.
*   **Performance:** See [PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md) for details on optimizations and benchmarks.

## Installation

Add `graph_os_store` (or the correct package name if different) to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:graph_os_store, "~> 0.1.0"} # Replace with actual package name and version
  ]
end
```

Then, run `mix deps.get`.

## Basic Usage

```elixir
# Start the default store (implicitly named :default)
# Note: Using start_link is preferred in applications/supervisors
{:ok, _pid} = GraphOS.Store.start_link(name: :default)

# Define basic node/edge modules (or use custom ones)
alias GraphOS.Entity.Node
alias GraphOS.Entity.Edge

# Insert a node into the default store
{:ok, node_a} = GraphOS.Store.insert(Node, %{data: %{name: "Alice"}})
{:ok, node_b} = GraphOS.Store.insert(Node, %{data: %{name: "Bob"}})

# Insert an edge connecting the nodes
# Note: Default store is used if `store:` option is omitted
{:ok, edge} = GraphOS.Store.insert(Edge, %{source: node_a.id, target: node_b.id, data: %{type: "knows"}})

# Get a node
{:ok, retrieved_node} = GraphOS.Store.get(Node, node_a.id)
IO.inspect retrieved_node

# Update a node's data
{:ok, updated_node} = GraphOS.Store.update(Node, %{id: node_a.id, data: %{name: "Alice Smith"}})
IO.inspect updated_node

# List all nodes
{:ok, all_nodes} = GraphOS.Store.all(Node)
IO.inspect all_nodes

# Delete an edge
:ok = GraphOS.Store.delete(Edge, edge.id)

# Stop the default store
GraphOS.Store.stop(:default)
```

## Using Multiple Named Stores

You can run multiple independent stores simultaneously by giving them unique names. This is useful for separating different datasets, configurations, or for testing.

**Starting Named Stores:**

Use the `:name` option when starting the store. The name should be an atom.

```elixir
# Start two named stores
{:ok, _pid1} = GraphOS.Store.start_link(name: :store_users)
{:ok, _pid2} = GraphOS.Store.start_link(name: :store_products, adapter: GraphOS.Store.Adapter.ETS, compressed: true) # Example with options
```

**Interacting with Named Stores:**

To interact with a specific named store, pass the `store:` option with the store's name to the `GraphOS.Store` functions. If the `store:` option is omitted, GraphOS.Store attempts to use the store named `:default`.

```elixir
alias GraphOS.Entity.Node

# Insert a node into the :store_users store
{:ok, user_node} = GraphOS.Store.insert(Node, %{data: %{name: "Charlie"}}, store: :store_users)

# Insert a node into the :store_products store
{:ok, product_node} = GraphOS.Store.insert(Node, %{data: %{name: "Gadget"}}, store: :store_products)

# Get the user node
{:ok, retrieved_user} = GraphOS.Store.get(Node, user_node.id, store: :store_users)

# This would fail because product_node is not in :store_users
# {:error, :not_found} = GraphOS.Store.get(Node, product_node.id, store: :store_users)

# Stop the named stores
GraphOS.Store.stop(:store_users)
GraphOS.Store.stop(:store_products)
```

### Named Stores for Testing (Important!)

Using named stores is the **recommended approach for testing**. It allows each test (or test suite) to run against an isolated, clean data store, preventing interference between tests.

**Common ExUnit Pattern:**

```elixir
defmodule MyApp.GraphTest do
  use ExUnit.Case, async: true # Run tests concurrently

  alias GraphOS.Store
  alias GraphOS.Entity.{Node, Edge}

  # Setup block runs before each test
  setup do
    # 1. Generate a unique store name for this test
    # Using the test module name + unique integer ensures isolation
    store_name = :"#{__MODULE__}_#{System.unique_integer()}"

    # 2. Start the store with the unique name
    {:ok, store_pid} = Store.start_link(name: store_name)

    # 3. Pass the store name to the test context
    # Also, ensure the store is stopped after the test using `on_exit`
    on_exit(fn -> Store.stop(store_name) end)

    # Return the context for the test
    %{store_name: store_name}
  end

  # Example test using the named store from context
  test "inserts and retrieves a node", %{store_name: store_name} do
    # 4. Use the store_name from context when calling Store functions
    {:ok, inserted_node} = Store.insert(Node, %{data: %{label: "Test"}}, store: store_name)

    assert inserted_node.id != nil

    {:ok, retrieved_node} = Store.get(Node, inserted_node.id, store: store_name)
    assert retrieved_node.id == inserted_node.id
    assert retrieved_node.data.label == "Test"
  end

  test "handles edges correctly", %{store_name: store_name} do
    {:ok, node1} = Store.insert(Node, %{}, store: store_name)
    {:ok, node2} = Store.insert(Node, %{}, store: store_name)

    {:ok, edge} = Store.insert(Edge, %{source: node1.id, target: node2.id}, store: store_name)
    assert edge.id != nil

    {:ok, retrieved_edge} = Store.get(Edge, edge.id, store: store_name)
    assert retrieved_edge.source == node1.id
  end
end
```

**Key takeaways for testing:**

*   **Use `setup`:** Start a uniquely named store for each test.
*   **Pass Context:** Make the `store_name` available in the test context.
*   **Specify `store:`:** Always use the `store: store_name` option when calling `GraphOS.Store` functions within your test.
*   **Clean Up:** Use `on_exit` or the `setup` return tuple (`{:ok, pid: store_pid, store_name: store_name}`) to ensure the test store is stopped after the test finishes, freeing up resources and the name.
*   **`async: true`:** Using unique stores allows tests to run concurrently safely.

## Custom Node and Edge Types

You can define custom modules for nodes and edges with specific schemas and helper functions.

```elixir
# Example: lib/my_app/user.ex
defmodule MyApp.User do
  use GraphOS.Entity.Node, # Use the Node behaviour
    schema: %{ # Define a schema for validation
      fields: [
        %{name: :name, type: :string, required: true},
        %{name: :email, type: :string, format: :email}
      ]
    }

  # Add custom functions specific to User nodes
  def create(name, email, opts \\ []) do
    GraphOS.Store.insert(__MODULE__, %{name: name, email: email}, opts)
  end
end

# Example: lib/my_app/friendship.ex
defmodule MyApp.Friendship do
  use GraphOS.Entity.Edge, # Use the Edge behaviour
    source: MyApp.User, # Specify allowed source type (optional)
    target: MyApp.User, # Specify allowed target type (optional)
    schema: %{
      fields: [
        %{name: :since, type: :utc_datetime}
      ]
    }

  def create(user1_id, user2_id, since_datetime, opts \\ []) do
    GraphOS.Store.insert(__MODULE__, %{
      source: user1_id,
      target: user2_id,
      data: %{since: since_datetime}
    }, opts)
  end
end

# Usage with custom types:
# {:ok, user} = MyApp.User.create("Bob", "bob@example.com", store: :my_store)
# {:ok, friend_edge} = MyApp.Friendship.create(user1.id, user2.id, DateTime.utc_now(), store: :my_store)
```

## Access Control

GraphOS includes modules for managing access control based on policies, actors, and groups. (See `GraphOS.Access` modules and tests for details).

```elixir
# Simplified Example
# Setup (Policies, Actors, Groups, Permissions need to be created first)
# policy_id = ...
# actor_id = ...
# resource = "document:123"
# action = :read

# Check permission
allowed? = GraphOS.Access.has_permission?(policy_id, actor_id, resource, action)

if allowed? do
  # Proceed with operation
else
  # Deny access
end
```

## Graph Algorithms

Use `GraphOS.Store.traverse/3` to execute graph algorithms.

```elixir
# Find shortest path using Dijkstra's
{:ok, path_nodes, weight} = GraphOS.Store.traverse(store_name, :shortest_path, {node_a.id, node_b.id, [weight_property: "distance"]})

# Find connected components
{:ok, components} = GraphOS.Store.traverse(store_name, :connected_components)

# Calculate PageRank
{:ok, scores} = GraphOS.Store.traverse(store_name, :page_rank, [iterations: 30])

# See lib/store/algorithm/README.md for more details and options.
```

## Development

**Run Tests:**

```bash
mix test
```

**Check Test Coverage:**

```bash
mix coveralls.html
```

**Run Code Linter:**

```bash
mix credo
```

**Generate Documentation:**

```bash
mix docs
```

## Contributing

Please refer to the contribution guidelines (if available) and ensure code quality checks pass before submitting pull requests.