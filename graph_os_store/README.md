# GraphOS.Store

GraphOS.Store (previously GraphOS.Graph) is the main entrypoint for storing data or state for GraphOS.Core modules.

## Overview

GraphOS.Store provides a minimal interface for storing and retrieving graph data using different storage engines.
Currently, only an ETS-based implementation is provided, but the architecture is designed to allow for other
storage adapters to be added in the future.

## Features

- Simple API for storing and retrieving data
- Support for multiple stores in the same application
- Schema-based data validation
- Support for custom node and edge types
- Subscription system for real-time updates
- Access control and permission management
- Graph algorithms for data analysis and traversal

## Development Status

- **Tests**: 123 tests, 0 failures, 1 skipped (related to OperationGuard hooks)
- **Coverage**: 52.4% overall test coverage (run `mix coveralls.html` for detailed report)
- **Code Quality**: Monitored via Credo (run `mix credo` for analysis)

See [TASKS.md](TASKS.md) for a detailed breakdown of module status and future development plans.

## Usage

### Basic usage

```elixir
# Start the store
GraphOS.Store.start()

# Insert a node
{:ok, node} = GraphOS.Store.insert(:node, %{type: "person", data: %{name: "John"}})

# Insert an edge
{:ok, edge} = GraphOS.Store.insert(:edge, %{source: node.id, target: "other_node_id", type: "knows"})

# Update a node
{:ok, updated_node} = GraphOS.Store.update(:node, %{id: node.id, data: %{name: "John Doe"}})

# Get a node
{:ok, retrieved_node} = GraphOS.Store.get(:node, node.id)

# Delete a node
:ok = GraphOS.Store.delete(:node, node.id)

# Stop the store
GraphOS.Store.stop()
```

### Using multiple stores

```elixir
# Start stores with different names
GraphOS.Store.start(name: :store1)
GraphOS.Store.start(name: :store2)

# Use a specific store
{:ok, node} = GraphOS.Store.insert(:node, %{type: "person"}, store: :store1)

# Clean up
GraphOS.Store.stop(:store1)
GraphOS.Store.stop(:store2)
```

### Custom node types

```elixir
defmodule MyApp.Graph do
  use GraphOS.Store.Graph
end

defmodule MyApp.User do
  use GraphOS.Store.Node,
    graph: MyApp.Graph,
    schema: %{
      name: :user,
      fields: [
        %{name: :id, type: :string, required: true},
        %{name: :name, type: :string, required: true},
        %{name: :email, type: :string}
      ]
    }

  def create(name, email) do
    GraphOS.Store.insert(__MODULE__, %{
      name: name,
      email: email
    })
  end

  def set_email(user, email) do
    GraphOS.Store.update(__MODULE__, %{id: user.id, email: email})
  end
end
```

### Custom edge types

```elixir
defmodule MyApp.Friendship do
  use GraphOS.Store.Edge,
    graph: MyApp.Graph,
    source: MyApp.User,
    target: MyApp.User

  def create(user1, user2, strength \\ 1) do
    GraphOS.Store.insert(__MODULE__, %{
      source: user1.id,
      target: user2.id,
      data: %{strength: strength}
    })
  end
end
```

### Access Control

```elixir
# Create a policy
{:ok, policy} = GraphOS.Access.create_policy(%{name: "document_policy"})

# Add an actor (user)
{:ok, actor} = GraphOS.Access.create_actor(%{id: "user_123", type: "user"})

# Grant permissions
GraphOS.Access.grant_permission(policy.id, actor.id, "document", "read")
GraphOS.Access.grant_permission(policy.id, actor.id, "document", "write")

# Check permissions
GraphOS.Access.has_permission?(policy.id, actor.id, "document", "read") # true
GraphOS.Access.has_permission?(policy.id, actor.id, "document", "delete") # false

# Create a group and add members
{:ok, group} = GraphOS.Access.create_group(%{id: "editors", name: "Editors"})
GraphOS.Access.add_to_group(group.id, actor.id)

# Grant permissions to a group
GraphOS.Access.grant_permission(policy.id, group.id, "document", "edit")

# Members inherit group permissions
GraphOS.Access.has_permission?(policy.id, actor.id, "document", "edit") # true
```

### Graph Algorithms

```elixir
# Find all paths using BFS
{:ok, paths} = GraphOS.Store.execute(%{
  type: :algorithm,
  algorithm: :bfs,
  start: start_node_id,
  options: %{max_depth: 3, direction: :outgoing}
})

# Find shortest path
{:ok, path} = GraphOS.Store.execute(%{
  type: :algorithm,
  algorithm: :shortest_path,
  start: start_node_id,
  target: target_node_id,
  options: %{weight_property: :distance}
})
```

## Installation

The package can be installed by adding `graph_os_graph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:graph_os_graph, "~> 0.1.0"}
  ]
end
```

## Development

### Testing

Run the test suite:

```bash
mix test
```

Generate a test coverage report:

```bash
mix coveralls.html
```

Run code analysis:

```bash
mix credo
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

## Transactions

```elixir
# Create operations
op1 = %{type: :insert, entity_type: :node, data: %{type: "person", data: %{name: "John"}}}
op2 = %{type: :insert, entity_type: :node, data: %{type: "person", data: %{name: "Jane"}}}

# Build a transaction
transaction = GraphOS.Store.Transaction.new([op1, op2])

# Execute the transaction
{:ok, results} = GraphOS.Store.execute(transaction)
```

## Subscription API

The subscription API allows you to subscribe to changes in the store and receive real-time notifications.

```elixir
# Subscribe to all user entities
{:ok, sub_id} = GraphOS.Store.subscribe(MyApp.User)

# Subscribe to a specific user entity
{:ok, sub_id} = GraphOS.Store.subscribe({MyApp.User, "user123"})

# Subscribe to a custom topic
{:ok, sub_id} = GraphOS.Store.subscribe("user:login", events: [:create])

# Receive notifications
receive do
  {:graph_os_store, topic, event} ->
    IO.puts("Received event: #{inspect(event)}")
end

# Publish a custom event
event = %GraphOS.Store.Event{
  type: :custom,
  topic: "user:login",
  entity_type: :node,
  entity_id: "user123",
  metadata: %{ip_address: "192.168.1.1"}
}
:ok = GraphOS.Store.publish(event)

# Unsubscribe when done
:ok = GraphOS.Store.unsubscribe(sub_id)