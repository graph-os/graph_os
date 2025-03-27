# GraphOS Module Testing Status

This document tracks the testing status of modules in the GraphOS project.

## Entity Modules

| Module | Test File | Testing Status | Testing Keywords |
|--------|-----------|----------------|-----------------|
| GraphOS.Entity.Graph | test/entity/graph_test.exs | ✅ Tested | Creating graphs, schema validation, behavior callbacks, custom implementations |
| GraphOS.Entity.Node | test/entity/node_test.exs | ✅ Tested | Creating nodes, custom node types, schema validation, data_schema implementation |
| GraphOS.Entity.Edge | test/entity/edge_test.exs | ✅ Tested | Creating edges, binding constraints, schema validation, data_schema implementation |
| GraphOS.Entity.Metadata | test/entity/metadata_test.exs | ✅ Tested | Schema validation, deleted? function, manual metadata handling |
| GraphOS.Entity.Binding | test/entity/binding_test.exs | ✅ Tested | Creating bindings, allowed? function, included?/excluded? functions, validate! function |
| GraphOS.Entity.SchemaBehaviour | None | ❌ Not Tested | Should test implementations of callbacks |
| GraphOS.Entity (main module) | None | ❌ Not Tested | from_module_opts/1, get_type/1, generate_id/0 |

## Store Modules

| Module | Test File | Testing Status | Testing Keywords |
|--------|-----------|----------------|-----------------|
| GraphOS.Store | test/store_test.exs | ✅ Tested | Basic CRUD operations, transactions, queries |
| GraphOS.Store.Adapter.ETS | test/store/adapter/ets_test.exs | ✅ Tested | Initialization, CRUD operations, querying |

## Algorithm Modules

| Module | Test File | Testing Status | Testing Keywords |
|--------|-----------|----------------|-----------------|
| GraphOS.Store.Algorithm.BFS | test/store/algorithm/bfs_test.exs | ✅ Tested | Path traversal, options, filtering |
| GraphOS.Store.Algorithm.ShortestPath | None | ❌ Not Tested | Path finding, edge weights, disconnected graphs |
| GraphOS.Store.Algorithm.PageRank | None | ❌ Not Tested | Ranking nodes, convergence, damping factor |
| GraphOS.Store.Algorithm.ConnectedComponents | None | ❌ Not Tested | Component identification, large graphs |
| GraphOS.Store.Algorithm.MinimumSpanningTree | None | ❌ Not Tested | Tree building, edge weights, disconnected graphs |
| GraphOS.Store.Algorithm.Weights | None | ❌ Not Tested | Weight calculations, property mapping |

## Access Modules

| Module | Test File | Testing Status | Testing Keywords |
|--------|-----------|----------------|-----------------|
| GraphOS.Access | test/access/access_test.exs, test/access/access_basic_test.exs | ✅ Tested | High-level API, policy creation, permission checks |
| GraphOS.Access.Policy | test/access/access_test.exs | ✅ Tested | Creation, retrieval, management |
| GraphOS.Access.Actor | test/access/actor_scope_test.exs | ✅ Tested | Creation, validation |
| GraphOS.Access.Scope | test/access/actor_scope_test.exs | ✅ Tested | Creation, validation |
| GraphOS.Access.Permission | test/access/access_test.exs | ✅ Tested | Permission grants, permission checks |
| GraphOS.Access.Group | test/access/group_membership_test.exs | ✅ Tested | Group management, membership |
| GraphOS.Access.Membership | test/access/group_membership_test.exs | ✅ Tested | Member operations, group relationships |
| GraphOS.Access.OperationGuard | test/access/operation_guard_test.exs | ✅ Tested | Permission enforcement, access control |

## Testing Priorities

1. **High Priority**
   - GraphOS.Entity (main module)
   - GraphOS.Store.Algorithm modules beyond BFS

2. **Medium Priority**
   - GraphOS.Entity.SchemaBehaviour
   - Any utility modules
   - Entity.Protocol implementations

3. **Low Priority**
   - Test refinement for existing tests
   - Performance testing

## Test Focus Areas

- **Entity Modules**: Focus on proper creation, schema validation, and behavior implementations
- **Store Modules**: Focus on data integrity, CRUD operations, and querying
- **Algorithm Modules**: Focus on correctness with various graph sizes and structures
- **Access Modules**: Focus on permission models and security guarantees
