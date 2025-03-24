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