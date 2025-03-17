# GraphOS Refactoring Plan

This document outlines a comprehensive plan to refactor the GraphOS architecture to improve component boundaries, separation of concerns, and integration capabilities.

## Problem Statement

Current issues in the GraphOS architecture:

1. Boundary violations between apps
2. Protocol adapters mixed with graph implementation
3. Access control references cross-cutting through apps
4. Custom plug implementation instead of standard Plug
5. Potential overuse of GenServer where GenStage might be more appropriate

## Refactoring Goals

1. Clarify component boundaries
2. Separate protocol concerns from core graph implementation
3. Standardize on official Plug for HTTP/web interfaces
4. Improve the flow of data processing with GenStage where appropriate
5. Create a more maintainable and extensible architecture

## Phase 1: Move Adapters Out of Graph Library ✅

**Status: COMPLETED**

The first phase of the refactoring has been completed with the following changes:

1. Created a new `GraphOS.Adapter` namespace in graph_os_core as the central entry point for adapters
2. Implemented core adapter functionality in graph_os_core:
   - `GraphOS.Adapter.GraphAdapter` (behavior definition)
   - `GraphOS.Adapter.Context` (request/response context)
   - `GraphOS.Adapter.Server` (GenServer implementation)
   - `GraphOS.Adapter.PlugAdapter` (middleware system)
   - `GraphOS.Adapter.GenServer` (sample adapter)

3. Created compatibility modules in graph_os_graph to maintain backward compatibility:
   - Modified existing adapter modules to delegate to new implementations
   - Added deprecation notices to old modules
   - Ensured existing code continues to work through the transition

4. Added gen_stage dependency to graph_os_core for future pipeline implementations

5. Updated boundary definitions to expose new adapter modules

### Test Status

The core functionality tests pass successfully, but the adapter-specific tests still need to be moved and updated. This will be addressed in Phase 3 as we migrate to the graph_os_protocol application.

### Original Plan (For Reference)

Files moved:
- `/apps/graph_os_graph/lib/graph/adapter.ex` → `/apps/graph_os_core/lib/graph_os/adapter/graph_adapter.ex`
- `/apps/graph_os_graph/lib/graph/adapter/context.ex` → `/apps/graph_os_core/lib/graph_os/adapter/context.ex`
- `/apps/graph_os_graph/lib/graph/adapter/server.ex` → `/apps/graph_os_core/lib/graph_os/adapter/server.ex`
- `/apps/graph_os_graph/lib/graph/adapters/gen_server.ex` → `/apps/graph_os_core/lib/graph_os/adapter/gen_server.ex`
- `/apps/graph_os_graph/lib/graph/plug.ex` → `/apps/graph_os_core/lib/graph_os/adapter/plug_adapter.ex`

Tests to be moved in Phase 3:
- `/apps/graph_os_graph/test/graph/adapter/adapter_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/adapter_test.exs`
- `/apps/graph_os_graph/test/graph/adapter/gen_server_adapter_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/gen_server_adapter_test.exs`
- `/apps/graph_os_graph/test/graph/adapter/grpc_adapter_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/grpc_adapter_test.exs`
- `/apps/graph_os_graph/test/graph/adapter/jsonrpc_adapter_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/jsonrpc_adapter_test.exs`
- `/apps/graph_os_graph/test/graph/adapter/mcp_adapter_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/mcp_adapter_test.exs`
- `/apps/graph_os_graph/test/graph/adapter/plug_test.exs` → `/apps/graph_os_core/test/graph_os/adapter/plug_adapter_test.exs`

## Phase 2: Create Clean Interface for Access Control ✅

**Status: COMPLETED**

Phase 2 of the refactoring has been completed with the following changes:

1. Created a new `GraphOS.Graph.Access` behaviour in graph_os_graph:
   - Defined a clear interface with authorization callbacks
   - Provided type specifications for operation types and contexts
   - Added comprehensive documentation with usage examples

2. Implemented `GraphOS.Core.Access.GraphAccess` in graph_os_core:
   - Created a complete implementation of the `GraphOS.Graph.Access` behaviour
   - Added delegation to the existing `GraphOS.Core.AccessControl` system
   - Implemented fine-grained authorization for nodes, edges, and operations

3. Updated `GraphOS.Graph.Store` to support access control:
   - Added access control hooks to all graph operations
   - Implemented context-passing for all store functions
   - Created helper functions for access context creation

4. Enhanced `GraphOS.Graph.Store.ETS` to work with the access system:
   - Added access control support to init function
   - Set up storage for access control configuration

5. Updated `GraphOS.Core.AccessControl` to integrate with the new interface:
   - Added helper functions for access context creation
   - Improved pattern matching for resource permissions
   - Enhanced documentation with examples of the new interface

### Files Created/Modified
- `/apps/graph_os_graph/lib/graph/access.ex` - New behaviour definition
- `/apps/graph_os_core/lib/graph_os/core/access/graph_access.ex` - New implementation
- `/apps/graph_os_graph/lib/graph/store.ex` - Updated with access control hooks
- `/apps/graph_os_graph/lib/graph/store/ets.ex` - Enhanced for access control
- `/apps/graph_os_core/lib/graph_os/core/access_control.ex` - Improved integration

## Phase 2.5: Clean Up Graph Library and Add Subscription Interface ✅

**Status: COMPLETED**

Phase 2.5 of the refactoring has been completed with the following changes:

1. Removed execution-related code from graph_os_graph:
   - Removed GraphOS.Graph.execute_node and execute_node_by_id functions
   - Removed check_execute_permission helper functions
   - Removed unused extractor functions

2. Added subscription system to graph_os_graph:
   - Created GraphOS.Graph.Subscription behavior with a clear interface
   - Added a lightweight GraphOS.Graph.Subscription.NoOp implementation
   - Added subscription-related convenience functions to GraphOS.Graph
   - Added tests for the subscription system

3. Updated Access interface to focus on core interfaces:
   - Refocused to match only Transaction, Operation, Query, and Subscription
   - Removed direct references to nodes and edges
   - Added higher-level authorization functions
   - Added generic filter_results function

4. Removed Application module and other infrastructure:
   - Removed GraphOS.Graph.Application module
   - Updated mix.exs to remove application callback
   - Removed redundant adapter tests

5. Simplified serialization:
   - Removed encoders/jason_encoder.ex
   - Used built-in @derive directive for JSON encoding
   - Fixed JSON encoding warnings

6. Updated documentation:
   - Updated BOUNDARIES.md to reflect new architecture
   - Updated CLAUDE.md with new modules and responsibilities
   - Added explicit descriptions of what doesn't belong in the graph library

### Files Created/Modified
- `/apps/graph_os_graph/lib/graph.ex` - Removed execution code, added subscription functions
- `/apps/graph_os_graph/lib/graph/access.ex` - Redesigned interface
- `/apps/graph_os_graph/lib/graph/subscription.ex` - New subscription behavior
- `/apps/graph_os_graph/lib/graph/subscription/noop.ex` - No-op implementation
- `/apps/graph_os_graph/test/graph/access_test.exs` - Updated tests
- `/apps/graph_os_graph/test/graph/subscription_test.exs` - New tests
- `/apps/graph_os_graph/mix.exs` - Removed application callback
- `/apps/graph_os_graph/BOUNDARIES.md` - Updated boundaries
- `/apps/graph_os_graph/CLAUDE.md` - Updated documentation

### Files Removed
- `/apps/graph_os_graph/lib/graph/application.ex` - Application module
- `/apps/graph_os_graph/lib/graph/encoders/jason_encoder.ex` - Custom encoder
- `/apps/graph_os_graph/test/graph/adapter/*` - Adapter tests
- `/apps/graph_os_graph/test/support/schema_factory.ex` - Unused factory

## Phase 3: Create New graph_os_protocol Application

### New Application Structure
```
/apps/graph_os_protocol/
  /lib/
    /graph_os/protocol.ex
    /graph_os/protocol/
      /plug.ex - Standard Plug implementation
      /http.ex - HTTP interface
      /router.ex - Routing logic
      /controllers/ - HTTP controllers
      /json_rpc.ex - JSON-RPC implementation
      /grpc.ex - gRPC implementation
      /sse.ex - Server-sent events
  /test/
    /graph_os/protocol/
      /plug_test.exs
      /http_test.exs
      /router_test.exs
      /json_rpc_test.exs
      /grpc_test.exs
      /sse_test.exs
  mix.exs
  README.md
```

### Required Code Changes
1. Create new app with dependencies on `:plug` and `:phoenix` (optional)
2. Implement standard Plug-compliant interfaces
3. Migrate protocol logic from adapters
4. Create proper routers and controllers

## Phase 4: Convert Key Flows to GenStage

### Flows to Convert
1. Code Analysis Pipeline

```elixir
# New structure in /apps/graph_os_core/lib/graph_os/core/code_graph/pipeline/
defmodule GraphOS.Core.CodeGraph.Pipeline do
  # Producer: File sources
  defmodule FileProducer do
    use GenStage
    # Implementation
  end
  
  # Producer-Consumer: Code parser
  defmodule CodeParser do
    use GenStage
    # Implementation
  end
  
  # Producer-Consumer: AST analyzer
  defmodule ASTAnalyzer do
    use GenStage
    # Implementation
  end
  
  # Consumer: Graph builder
  defmodule GraphBuilder do
    use GenStage
    # Implementation
  end
  
  # Pipeline supervisor
  defmodule Supervisor do
    use Supervisor
    # Implementation to connect stages
  end
end
```

2. Git Integration Events

```elixir
# New structure in /apps/graph_os_core/lib/graph_os/core/git/pipeline/
defmodule GraphOS.Core.Git.Pipeline do
  # Producer: Git events
  defmodule EventProducer do
    use GenStage
    # Implementation
  end
  
  # Producer-Consumer: Event classifier
  defmodule EventClassifier do
    use GenStage
    # Implementation
  end
  
  # Consumer: Graph updater
  defmodule GraphUpdater do
    use GenStage
    # Implementation
  end
  
  # Pipeline supervisor
  defmodule Supervisor do
    use Supervisor
    # Implementation to connect stages
  end
end
```

## Phase 5: Update Boundary Definitions ✅

**Status: COMPLETED**

Phase 5 of the refactoring has been completed with the following changes:

1. Updated `/BOUNDARIES.md` with the new component architecture:
   - Defined clear responsibilities for each component
   - Established graph_os_graph as a pure graph data structure library
   - Moved infrastructure concerns to graph_os_core
   - Added graph_os_protocol as a dedicated protocol layer
   - Defined precise public APIs for each component
   - Updated dependency flow between components

2. The new architecture follows these principles:
   - **graph_os_graph**: Pure graph data structure with algorithm implementations
   - **graph_os_core**: Application infrastructure and cross-cutting concerns
   - **graph_os_protocol**: Protocol interfaces using standard libraries
   - **graph_os_dev**: Development tools and interfaces

3. Clarified module responsibilities:
   - Access control interface in graph_os_graph, implementation in graph_os_core
   - Protocol concerns moved entirely to graph_os_protocol
   - Application lifecycle management centralized in graph_os_core

### Files Updated
- `/BOUNDARIES.md` - Complete revision with new component architecture

### Files To Update (Pending)
- Each app's `/CLAUDE.md` - Update with revised boundaries
- Each app's `mix.exs` - Update boundary definitions

## Implementation Strategy

### Order of Operations
1. Begin with adapter movement (Phase 1)
2. Implement access control interface (Phase 2)
3. Create protocol app (Phase 3)
4. Convert key flows to GenStage (Phase 4)
5. Update boundary documentation (Phase 5)

### Testing Strategy
1. Maintain existing tests during migration
2. Create integration tests that verify boundaries
3. Test protocol interfaces with standard Plug testing tools
4. Test GenStage pipelines with concurrency tests
5. Properly document skipped tests for incomplete features:
   - Add clear TODO comments explaining what needs to be implemented
   - Explain why the test is skipped and what it will validate
   - Use appropriate tags (@tag :skip) to exclude them from normal test runs
   - Follow the guidelines in CLAUDE.md "Handling Incomplete Implementations and TODOs" section

## Dependencies and Version Updates

- Add `{:gen_stage, "~> 1.2"}` to relevant apps
- Add `{:plug, "~> 1.14"}` to protocol app
- Consider `{:phoenix, "~> 1.7"}` for protocol app (optional)
- Ensure boundary dependency is consistent across apps

## Migration Path for Clients

1. Provide compatibility modules during transition
2. Document new integration points
3. Create examples of integration with Phoenix, Plug, and other frameworks
4. Update client libraries to use new protocol interfaces

## Metrics for Success

- Reduced coupling between components
- Clear and enforceable boundaries
- Improved performance in data processing flows
- Standard compliance with Plug ecosystem
- Easier integration with external systems