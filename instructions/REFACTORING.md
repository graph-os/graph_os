## GraphOS.Store Refactoring Tasks

This document outlines the remaining tasks for the GraphOS.Store refactoring.

## 1. File Status and Pending Tasks

### 1.1 Main Files

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/schema.ex` | ✅ IMPLEMENTED | Add missing typespecs, review API for consistency |
| `apps/graph_os_graph/lib/store.ex` | ✅ IMPLEMENTED | Add typespecs, standardize return types, improve error handling |

### 1.2 Store Directory

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/store/access.ex` | ❌ REMOVE | Remove completely, no deprecation period |
| `apps/graph_os_graph/lib/store/algorithm.ex` | ⚠️ NEEDS UPDATE | Update API calls to use new Store interface |
| `apps/graph_os_graph/lib/store/application.ex` | ✅ IMPLEMENTED | Review for potential improvements, add typespecs |
| `apps/graph_os_graph/lib/store/edge.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve validation |
| `apps/graph_os_graph/lib/store/graph.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve validation |
| `apps/graph_os_graph/lib/store/meta.ex` | ⚠️ NEEDS UPDATE | Update to align with new API or consider complete removal |
| `apps/graph_os_graph/lib/store/node.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve validation |
| `apps/graph_os_graph/lib/store/operation.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve validation |
| `apps/graph_os_graph/lib/store/protocol.ex` | ❌ REMOVE | Remove completely, no deprecation period |
| `apps/graph_os_graph/lib/store/query.ex` | ⚠️ NEEDS UPDATE | Fix mixed old/new implementation patterns, ensure consistency |
| `apps/graph_os_graph/lib/store/query_behaviour.ex` | ⚠️ NEEDS UPDATE | Update to align with new Query API or remove completely |
| `apps/graph_os_graph/lib/store/registry.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve error handling |
| `apps/graph_os_graph/lib/store/schema.ex` | ❌ REMOVE | Replace with GraphOS.Schema |
| `apps/graph_os_graph/lib/store/schema_behaviour.ex` | ❌ REMOVE | Replace with GraphOS.Schema |
| `apps/graph_os_graph/lib/store/store_adapter.ex` | ✅ IMPLEMENTED | Review for improvements, add typespecs |
| `apps/graph_os_graph/lib/store/subscription.ex` | ⚠️ NEEDS UPDATE | Update to work with new API |
| `apps/graph_os_graph/lib/store/transaction.ex` | ✅ IMPLEMENTED | Add missing typespecs, improve validation |

### 1.3 Algorithm Subdirectory

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/store/algorithm/*.ex` | ⚠️ NEEDS UPDATE | Update to work with new API, ensure efficiency with updated table structure |

### 1.4 Store Adapter Subdirectory

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/store/store_adapter/ets.ex` | ✅ IMPLEMENTED | Add missing typespecs, optimize for performance |

### 1.5 Subscription Subdirectory

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/store/subscription/*.ex` | ⚠️ NEEDS UPDATE | Update to work with new API |

### 1.6 Schema Subdirectory

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/lib/store/schema/*.ex` | ⚠️ NEEDS UPDATE | Migrate functionality to GraphOS.Schema |

## 2. Test Files

### 2.1 Main Test Files

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/test/store_test.exs` | 🔄 CREATE/UPDATE | Create if not exists, update to test new API |

### 2.2 Subdirectory Test Files

| File | Status | Remaining Tasks |
|------|--------|----------------|
| `apps/graph_os_graph/test/graph/access_test.exs` | ⚠️ NEEDS UPDATE | Update to work with new API |
| `apps/graph_os_graph/test/graph/algorithm_test.exs` | ⚠️ NEEDS UPDATE | Update to work with new API |
| `apps/graph_os_graph/test/graph/edge_test.exs` | ❌ REPLACE | Replace with new test for GraphOS.Store.Edge |
| `apps/graph_os_graph/test/graph/subscription_test.exs` | ⚠️ NEEDS UPDATE | Update to work with new API |
| `apps/graph_os_graph/test/support/graph_factory.ex` | ⚠️ NEEDS UPDATE | Update to work with new API |

### 2.3 Missing Test Files (To Create)

| File | Status | Tasks |
|------|--------|-------|
| `apps/graph_os_graph/test/schema_test.exs` | 🔄 CREATE | Create tests for GraphOS.Schema |
| `apps/graph_os_graph/test/store/graph_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Graph |
| `apps/graph_os_graph/test/store/node_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Node |
| `apps/graph_os_graph/test/store/edge_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Edge |
| `apps/graph_os_graph/test/store/operation_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Operation |
| `apps/graph_os_graph/test/store/transaction_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Transaction |
| `apps/graph_os_graph/test/store/query_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Query |
| `apps/graph_os_graph/test/store/registry_test.exs` | 🔄 CREATE | Create tests for GraphOS.Store.Registry |
| `apps/graph_os_graph/test/store/store_adapter/ets_test.exs` | 🔄 CREATE | Create tests for ETS adapter |

## 3. Consolidated Task List

### 3.1 Code Cleanup

- [ ] Remove `GraphOS.Store.Schema` since it's been replaced by `GraphOS.Schema`
- [ ] Remove `GraphOS.Store.SchemaBehaviour`
- [ ] Update all schema references to use the new schema module
- [ ] Remove deprecated code in `GraphOS.Store.start/1` method
- [ ] Clean up unused files and directories
- [ ] Review and clean up imports and aliases in all modules

### 3.2 API Consistency

- [ ] Fix mixed old/new patterns in the Query module
- [ ] Ensure consistent return types across all public APIs
- [ ] Standardize error handling approach throughout codebase
- [ ] Add typespecs for all public functions
- [ ] Improve validation for Operation and Query parameters

### 3.3 Module Updates

- [ ] Update `GraphOS.Store.Access` to work with the new API
- [ ] Update `GraphOS.Store.Algorithm` to work with the new API
- [ ] Update `GraphOS.Store.Subscription` to work with the new API
- [ ] Update `GraphOS.Store.Meta` or remove completely
- [ ] Remove `GraphOS.Store.Protocol` completely 
- [ ] Update `GraphOS.Store.QueryBehaviour` to align with the new Query API or remove completely

### 3.4 Boundary Integration

- [ ] Update boundary definitions to ensure clean dependencies
- [ ] Ensure no circular dependencies between modules
- [ ] Every module MUST have proper Boundary definitions

### 3.5 Testing

- [ ] Create missing test files for new modules
- [ ] Update existing tests to work with the new API
- [ ] Add tests for new functionality (Registry, multiple stores)
- [ ] Ensure test coverage for error cases

### 3.6 Documentation

- [ ] Update documentation for all public modules
- [ ] Update examples in README
- [ ] Add typespecs for all public functions

## 4. Implementation Notes

1. **Table Structure**:

```elixir
# Tables structure
table :graphs do
  field :id, :integer, required: true     # Auto-incrementing numeric ID
  field :module, :atom, required: true    # Graph module (e.g., GraphOS.Core.Access.Policy)
  field :temp, :boolean, default: false   # Whether this graph is temporary
  field :meta, :map, default: %{}         # Additional metadata
end

table :nodes do
  field :graph_id, :integer, required: true  # Reference to graphs.id
  field :id, :string, required: true         # Unique ID within the system
  field :type, :atom, required: true         # Module that defines this node type
  field :data, :map, required: true          # Node data/attributes
end

table :edges do
  field :graph_id, :integer, required: true  # Graph this edge belongs to
  field :id, :string, required: true         # Unique ID within the system
  field :type, :atom, required: true         # Module that defines this edge type
  field :source, :string, required: true     # Source node ID
  field :target, :string, required: true     # Target node ID
  field :data, :map, required: true          # Edge attributes
end
```

2. **Graph ID Management**:
   - Root graphs (like Access.Policy) should be assigned ID 0
   - Ensure graph IDs are consistent across restarts

3. **Performance Considerations**:
   - Benchmark updated implementation
   - Profile memory usage with large datasets
   
4. **Breaking Changes**:
   - API changes from GraphOS.Graph to GraphOS.Store
   - Schema definition syntax changes
   - Edge and Node behavior changes
   - Update all code that uses the old Graph API

## 5. Implementation Progress

The following components have been implemented:

✅ Minimal interface for `GraphOS.Store` with `start/0`, `stop/0`, `execute/1` methods
✅ Shorthand operations `insert/2`, `update/2`, `delete/1`, `get/2`
✅ `GraphOS.Store.Registry` for managing multiple stores
✅ `GraphOS.Store.Application` for starting the Registry as part of the application
✅ `GraphOS.Store.StoreAdapter` behavior for different storage engines
✅ ETS-based adapter implementation `GraphOS.Store.StoreAdapter.ETS`
✅ Core entity modules: `GraphOS.Store.Graph`, `GraphOS.Store.Node`, `GraphOS.Store.Edge`
✅ Operation, Query, and Transaction abstractions
✅ Moved schema functionality to `GraphOS.Schema`
✅ Custom node/edge type support with `use GraphOS.Store.Node` and `use GraphOS.Store.Edge`

⚠️ **Special Attention Needed**: 
- The `GraphOS.Store.Query` module currently has a mix of old and new implementation patterns. It implements the old `GraphOS.Store.QueryBehaviour` but also has new pattern methods)
- The boundary definitions have been updated but some unused modules are still exported.
- Return type inconsistencies exist in some APIs and need to be standardized.

## Remaining Tasks

### 4.1 Compatibility Considerations

1. **Breaking Changes**
   - API changes from GraphOS.Graph to GraphOS.Store
   - Schema definition syntax changes
   - Edge and Node behavior changes
   - Update all code that uses the old Graph API

2. **Performance Monitoring**
   - Benchmark updated implementation
   - Profile memory usage with large datasets

⚠️ **Special Attention Needed**: 
- The `GraphOS.Store.Query` module currently has a mix of old and new implementation patterns. It implements the old `GraphOS.Store.QueryBehaviour` but also has new pattern methods)
- The boundary definitions have been updated but some unused modules are still exported.
- Return type inconsistencies exist in some APIs and need to be standardized.


