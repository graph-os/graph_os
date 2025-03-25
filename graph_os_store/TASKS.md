# GraphOS.Store Next Tasks

> NOTE: Full reference can be found in [REFACTORING.md](REFACTORING.md)

## 1. Query API Extensions
- [x] Implement `all/1` function to retrieve all entities of a type (e.g., `GraphOS.Store.all(GraphOS.Store.Graph)`)
- [x] Add support for filtering in the `all/1` function
- [x] Ensure entity modules can define efficient query methods using Store's execute API
- [x] Consider adding helper methods for common query patterns

## 2. Documentation and Examples
- [x] Document entity type integration through macros (`__entity__/0`, `__store__/0`)
- [ ] Complete API documentation for all modules
- [ ] Add comprehensive examples for each feature
- [ ] Create user guide and cookbook
- [ ] Document the subscription API usage with Phoenix Channels

## 3. Testing
- [ ] Fix edge type restrictions tests
- [x] Add tests for entity type detection and integration
- [ ] Add more tests for complex queries and algorithms
- [ ] Add tests for subscription backpressure scenarios
- [ ] Add performance tests for critical operations

## 4. Performance Optimization
- [ ] Benchmark all core operations
- [ ] Identify and optimize bottlenecks
- [ ] Implement subscription backpressure handling
- [ ] Optimize event delivery for many subscribers

## 5. Example Applications
- [ ] Create a simple web application using the subscription API with Phoenix channels
- [ ] Build an example graph visualization with real-time updates
- [ ] Implement a collaborative graph editing example

## 6. Subscription API Enhancements
- [ ] Add support for backpressure control in subscription handlers
- [ ] Implement subscription batching for high-volume events
- [ ] Create helper functions for Phoenix channel integration
- [ ] Add metrics and monitoring for subscription performance

## 7. Advanced Search Capabilities
- [ ] Implement graph pattern matching search (similar to Cypher)
- [ ] Add support for property-based indexing to speed up lookups
- [ ] Create query optimization mechanisms for complex traversals
- [ ] Support for graph aggregation operations (count, min, max, etc.)

## 8. Persistence Layer
- [ ] Design persistence adapter interface
- [ ] Implement ETS backup/restore functionality
- [ ] Create a PostgreSQL adapter implementation
- [ ] Add support for incremental persistence (journaling)