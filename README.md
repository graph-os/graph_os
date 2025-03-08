# GraphOS

GraphOS is a modular, distributed graph operating system built with Elixir.

## Project Structure

GraphOS is organized as an umbrella application with multiple independent components:

* **GraphOS.Graph** (`graph_os_graph`): Core graph library providing data structures, algorithms, and storage
* **GraphOS.Core** (`graph_os_core`): OS functions such as access control and security
* **GraphOS.MCP** (`graph_os_mcp`): Model Context Protocol implementation for AI/LLM integration
* **GraphOS.Distributed** (`graph_os_distributed`): Distributed computing support using Horde
* **GraphOS.Livebook** (`graph_os_livebook`): Livebook integration for interactive graph analysis
* **GraphOS.Phoenix** (`graph_os_phoenix`): Phoenix integration for web-based graph interfaces

## Installation

Each component can be used independently by adding it to your dependencies:

```elixir
def deps do
  [
    {:graph_os_graph, "~> 0.1.0"},
    # Optional components
    {:graph_os_core, "~> 0.1.0"},
    {:graph_os_mcp, "~> 0.1.0"},
    {:graph_os_distributed, "~> 0.1.0"},
    {:graph_os_livebook, "~> 0.1.0"},
    {:graph_os_phoenix, "~> 0.1.0"}
  ]
end
```

## Running the Project

### Starting the Entire Umbrella Application

To start all components together:

```bash
# Clone the repository
git clone https://github.com/graph-os/graph_os.git
cd graph_os

# Get dependencies
mix deps.get

# Compile
mix compile

# Start the application
iex -S mix
```

### Starting Individual Components

Each component can be started independently:

#### GraphOS.Graph

```bash
cd graph_os/apps/graph_os_graph
iex -S mix
```

This will start the graph library with ETS storage.

#### GraphOS.Core

```bash
cd graph_os/apps/graph_os_core
iex -S mix
```

This will start the core OS services like access control.

#### GraphOS.MCP

```bash
cd graph_os/apps/graph_os_mcp
iex -S mix
```

This will start the MCP protocol server for AI/LLM integration.

## Development

```bash
# Run tests
mix test

# Run linting
mix lint

# Generate documentation
mix docs
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

