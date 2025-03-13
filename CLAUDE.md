# GraphOS Development Guide

## Project Structure
This is an Elixir umbrella project with the following hierarchy:
1. apps/tmux - Development tooling
2. apps/mcp - Communication protocol library
3. apps/graph_os_graph - Graph data structure
4. apps/graph_os_core - Core functionality
5. apps/graph_os_dev - Development interface

Dependencies flow downward only: apps can only depend on apps earlier in this list.

## Build/Test Commands
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Format code
mix format

# Run all tests
mix test

# Run a single test file
mix test path/to/test_file.exs

# Run tests for a specific app
cd apps/graph_os_core && mix test
```

## Mix Tasks
```bash
# Start Phoenix server in tmux session
mix dev.server

# Start MCP server with various interfaces
mix mcp.server     # Standard server
mix mcp.sse        # With SSE endpoint only
mix mcp.debug      # With debug mode (JSON only)
mix mcp.inspect    # With inspector UI
mix mcp.stdio      # With STDIO interface

# Run MCP type parity tests
mix mcp.type_parity
```

## Code Style Guidelines
- Use `mix format` for consistent formatting
- `snake_case` for variables/functions, `CamelCase` for modules
- Use `@moduledoc` and `@doc` for all modules and public functions
- Include `@spec` for public functions
- Group aliases alphabetically
- Use `{:ok, result}`/`{:error, reason}` tuples for operations that can fail
- Handle errors explicitly with pattern matching
- Keep functions small and focused on a single responsibility