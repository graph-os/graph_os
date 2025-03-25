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

## Installation

The package can be installed by adding `graph_os_graph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:graph_os_graph, "~> 0.1.0"}
  ]
end
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc).

## GraphOS.Store API

GraphOS.Store provides a minimal interface for storing and retrieving data using different storage engines (adapters).

### Main API

```elixir
# Initialize a store
{:ok, store_name} = GraphOS.Store.init()

# Insert a record
{:ok, user} = GraphOS.Store.insert(MyApp.User, %{data: %{name: "John"}})

# Get a record by ID
{:ok, user} = GraphOS.Store.get(MyApp.User, user_id)

# Update a record
{:ok, updated_user} = GraphOS.Store.update(MyApp.User, %{id: user_id, data: %{name: "John Updated"}})

# Delete a record
:ok = GraphOS.Store.delete(MyApp.User, user_id)

# Execute complex operations
query = GraphOS.Store.Query.traverse(node_id, algorithm: :bfs, max_depth: 3)
{:ok, result} = GraphOS.Store.execute(query)
```

### Custom Entity Definitions

You can define custom entities using the provided macros:

```elixir
# Define a graph
defmodule MyApp.Graph do
  use GraphOS.Store.Graph, temp: false

  @impl GraphOS.Store.Graph
  def on_start(options) do
    # Initialize graph on start
    {:ok, %{started_at: DateTime.utc_now()}}
  end
  
  @impl GraphOS.Store.Graph
  def on_stop(state) do
    # Cleanup when graph stops
    {:ok, state}
  end
end

# Define a node
defmodule MyApp.User do
  use GraphOS.Store.Node, graph: MyApp.Graph

  # Custom functions for this node type
  def set_name(user, name) do
    GraphOS.Store.update(__MODULE__, %{id: user.id, data: %{name: name}})
  end
end

# Define an edge with type restrictions
defmodule MyApp.Friendship do
  use GraphOS.Store.Edge,
    graph: MyApp.Graph,
    source: MyApp.User,
    target: MyApp.User

  # Custom functions for this edge type
  def set_strength(friendship, strength) do
    GraphOS.Store.update(__MODULE__, %{id: friendship.id, data: %{strength: strength}})
  end
end
```

### Transactions

For operations that need to be executed atomically:

```elixir
# Create operations
op1 = %GraphOS.Store.Operation{type: :insert, module: MyApp.User, params: %{data: %{name: "Alice"}}}
op2 = %GraphOS.Store.Operation{type: :insert, module: MyApp.User, params: %{data: %{name: "Bob"}}}

# Create a transaction
transaction = GraphOS.Store.Transaction.new([op1, op2])

# Execute the transaction
{:ok, results} = GraphOS.Store.execute(transaction)
```

### Advanced Queries

For more complex graph operations:

```elixir
# Traverse the graph from a node
query = GraphOS.Store.Query.traverse(start_node_id, algorithm: :bfs, max_depth: 3)
{:ok, nodes} = GraphOS.Store.execute(query)

# Find shortest path between nodes
query = GraphOS.Store.Query.shortest_path(source_id, target_id, weight_property: "distance")
{:ok, path, distance} = GraphOS.Store.execute(query)

# Find connected components
query = GraphOS.Store.Query.connected_components(edge_type: "friend")
{:ok, components} = GraphOS.Store.execute(query)
```

### Subscription API

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
```

For more details, see the [documentation](https://hexdocs.pm/graph_os_store).