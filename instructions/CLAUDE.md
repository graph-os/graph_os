# GraphOS Development Guide

## About This Document
This is the central development guide for GraphOS. It provides essential information for working with the codebase, including project structure, coding standards, and component-specific guidelines.

## Project Root and Directory Structure
This is an Elixir umbrella project where the root directory is `/Users/vegard/Developer/GraphOS/graph_os/`. 

When starting Claude from an application directory (e.g., `/Users/vegard/Developer/GraphOS/graph_os/apps/graph_os_graph/`), you're working in a component scope. From this component scope:

- The component's "root" is `/apps/graph_os_graph/`
- The project root is `../../` 
- All documentation is in the `../../instructions/` directory
- The CLAUDE.md file in your component directory is a symlink to `../../instructions/CLAUDE.md`

Always edit documentation files in the `/instructions` directory, never the symlinked copies in component directories.

## Documentation Structure
All documentation is centralized in the `/instructions` directory:

- **ARCHITECTURE.md**: Overall system architecture and design principles
- **BOUNDARIES.md**: Component boundaries and responsibilities
- **CLAUDE.md** (this file): Development guide and coding standards
- **HANDOFFS.md**: Cross-component task handoffs and coordination
- **README.md**: Documentation overview and maintenance guidelines
- **REFACTORING.md**: Refactoring guidelines and ongoing plans
- **TASKS.md**: Current and planned implementation tasks
- **index.md**: Quick navigation to all documentation

## Documentation Maintenance

### Important: Symlink System
All documentation files are **symlinked** from the `/instructions` directory to various locations:

1. **Root level**: `/ARCHITECTURE.md`, `/BOUNDARIES.md`, `/CLAUDE.md`, etc.
2. **App directories**: `/apps/*/BOUNDARIES.md`, `/apps/*/CLAUDE.md`, etc.

This ensures documentation is accessible from any location in the project.

### Editing Guidelines
- **ALWAYS edit files in the `/instructions` directory**, never the symlinked copies
- When updating component-specific details, also update the component's README.md
- Keep documentation in sync with code changes
- Use Markdown formatting consistently

### Adding New Documentation
1. Create the file in `/instructions/`
2. Create symlinks as needed
3. Update relevant README files and index.md

## Project Structure
This is an Elixir umbrella project with the following hierarchy:
1. **tmux** - Development tooling with mix tasks
2. **mcp** - Communication protocol library  
3. **graph_os_graph** - Core graph data structure
4. **graph_os_core** - Main functionality and components
5. **graph_os_protocol** - Protocol adapters
6. **graph_os_dev** - Development interface
7. **graph_os_cli** - Command line interface (Rust)

Dependencies flow downward only: apps can only depend on apps earlier in this list.

## Component Boundaries

Each component has strict boundaries and responsibilities. See [BOUNDARIES.md](./BOUNDARIES.md) for complete boundary documentation.

### Component Responsibilities:
- **tmux**: Development tooling with mix tasks for development workflows
- **mcp**: Communication protocol implementation, independent of GraphOS logic
- **graph_os_graph**: Core graph data structure and algorithms
- **graph_os_core**: Main GraphOS functionality, components, registries
- **graph_os_protocol**: Protocol interfaces (HTTP, JSON-RPC, gRPC, SSE)
- **graph_os_dev**: Phoenix UI and development server
- **graph_os_cli**: Terminal UI client interface (Rust)

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

## Testing Guidelines

### Testing Philosophy
- Tests should verify that code works in real-world scenarios
- Tests should validate business requirements and functional correctness
- Tests provide documentation of intended behavior
- Tests should catch regressions before they reach production

### Test Structure and Organization
- Place tests in the corresponding test directory mirroring the lib structure
- Name test files to match the module being tested with `_test.exs` suffix
- Group tests logically using `describe` blocks for related functionality
- Write clear test names that describe the behavior being tested

### Testing Best Practices
- **DO NOT** write tests that only verify mocks "for testing purposes"
- **DO** test actual behavior and outcomes, not implementation details
- **DO** use real dependencies when possible instead of mocks
- When mocks are necessary, they should:
  - Mimic real-world behavior closely
  - Be used to isolate the unit under test, not as a shortcut
  - Verify meaningful interactions, not trivial calls
- Focus on testing public interfaces, not internal implementation
- Test edge cases and error conditions, not just happy paths
- Keep tests independent and avoid test interdependencies
- Use setup functions for common test prerequisites

### Handling Incomplete Implementations and TODOs
- Mark tests for incomplete features with `@tag :skip` to exclude them from normal test runs
- Add clear comments before skipped tests explaining:
  - What functionality needs to be implemented (as a TODO)
  - Why the test is currently skipped
  - What the test is validating when it eventually runs
- Ensure skipped tests still represent the expected behavior
- Consider adding `@tag :todo` if your test framework supports it for better categorization
- Update test comments when the status of the implementation changes
- Review skipped tests regularly to ensure they stay relevant to the planned implementation

### Anti-patterns to Avoid
- Circular tests that only verify that mocks were called
- Tests that assert implementation details rather than behavior
- Overly complex test setups that are difficult to understand
- Brittle tests that break with minor implementation changes
- Tests that don't validate meaningful outcomes

### Integration and System Testing
- Include integration tests that verify components work together
- Include system tests that verify end-to-end behavior
- Test realistic scenarios that represent actual user workflows
- Test performance characteristics when relevant to requirements

## Component Guidelines

### graph_os_core

The GraphOS.Core component provides the central functionality of GraphOS, including the component system, code graph, executables, and access control.

#### Code Organization
- `lib/graph_os/core.ex` - Main GraphOS Core module
- `lib/graph_os/component.ex` - Component behavior
- `lib/graph_os/component/*.ex` - Component subsystems
- `lib/graph_os/core/code_graph/*.ex` - Code analysis and graph generation
- `lib/graph_os/core/executable/*.ex` - Executable management
- `lib/graph_os/core/access_control/*.ex` - Access control
- `lib/graph_os/core/git_integration.ex` - Git integration
- `lib/graph_os/core/mcp/*.ex` - MCP server implementations

#### Coding Guidelines
- Design clear component interfaces
- Follow the component pipeline pattern for processing
- Use contexts for passing state between components
- Document all public functions with examples
- Create detailed tests for component behaviors
- Ensure proper error handling and recovery
- Design for extensibility through component registration

### graph_os_graph

The GraphOS.Graph component provides the core graph data structure and algorithms for GraphOS. It is a pure graph library with no dependencies on other GraphOS components except potentially MCP for serialization.

#### Code Organization
- `lib/graph.ex` - Main graph interface
- `lib/graph/node.ex` - Node structure and operations
- `lib/graph/edge.ex` - Edge structure and operations
- `lib/graph/meta.ex` - Metadata structure
- `lib/graph/transaction.ex` - Transaction handling
- `lib/graph/operation.ex` - Operation definitions
- `lib/graph/protocol.ex` - Core protocol definition
- `lib/graph/access.ex` - Access control interface
- `lib/graph/subscription.ex` - Subscription interface
- `lib/graph/subscription/noop.ex` - No-op subscription implementation
- `lib/graph/store.ex` - Store behavior
- `lib/graph/store/*.ex` - Store implementations
- `lib/graph/algorithm.ex` - Algorithm module
- `lib/graph/algorithm/*.ex` - Algorithm implementations
- `lib/graph/query.ex` - Query interface
- `lib/graph/schema.ex` - Schema definitions
- `lib/graph/schema_behaviour.ex` - Schema behavior interface
- `lib/graph/schema/*.ex` - Schema implementations and utilities

#### Coding Guidelines
- Keep graph operations immutable by default
- Implement efficient graph algorithms
- Benchmark critical operations
- Document all public functions
- Maintain clear boundaries between graph structure and algorithms
- Use proper type specifications
- Create thorough test coverage for graph operations

#### Architecture Notes
- Graph operations should be composable
- Support both immutable and mutable (transactional) operations
- Store implementations should be pluggable
- Define extension points via behaviors
- Keep interface definitions separate from implementations
- Do not include application lifecycle management

#### Recent Architectural Changes
- Adapter implementations moved to GraphOS.Core and GraphOS.Protocol
- Access control interface kept here, implementation in GraphOS.Core
- Application lifecycle management moved to GraphOS.Core
- Node execution logic moved to GraphOS.Core
- Added Subscription interface with minimal implementation
- Refocused Access interface on core operations (Transaction, Operation, Query, Subscription)
- Removed redundant encoders and simplified serialization
- Added Schema system with protocol adapter support for GRPC and JSONRPC