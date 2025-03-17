# GraphOS.Core

GraphOS.Core provides the central functionality of GraphOS, including the component system, code graph, executables, and access control. It sits above graph_os_graph in the dependency hierarchy.

## Key Features

- Component system for modular functionality
- Code graph generation and analysis
- Executable graph management
- Access control implementation
- File watching and git integration
- MCP server implementations

## Documentation

For detailed documentation, please refer to the centralized documentation:

- [CLAUDE.md](../../instructions/CLAUDE.md) - Development guide with component details
- [BOUNDARIES.md](../../instructions/BOUNDARIES.md) - Component boundaries and API definitions

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
    {:graph_os_core, "~> 0.1.0"}
  ]
end
```