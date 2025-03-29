## Phased Improvement Plan (April 2025 Onwards - CTO Prioritization)

This plan outlines incremental improvements to GraphOS, focusing on **stability, core functionality, and maintainability** first, followed by performance enhancements and new features. Each phase represents a potential internal release milestone.

**CTO Rationale:** Our immediate priority is to solidify the core system. This means ensuring correctness through comprehensive testing (especially for algorithms and access control), improving the maintainability of critical components like the ETS adapter, and adding basic persistence to make GraphOS viable for real-world scenarios where data loss is unacceptable. Advanced performance tuning and new algorithms like A* will follow once this robust foundation is established.

**General Workflow for Each Phase/Major Task:**

1.  **Create Branch:** `git checkout -b feature/phaseX-<short-description>` (e.g., `feature/phase1-ets-quick-wins`)
2.  **Implement:** Make the code changes for the tasks in the phase. Adhere to coding standards.
3.  **Test:** Write and run unit/integration tests as specified. Ensure **all** tests pass (`mix test`). Aim to increase coverage.
4.  **Benchmark (if applicable):** Run relevant benchmarks (`mix graphos.benchmark` or specific test functions) to measure impact, especially for performance-related changes. Record results.
5.  **Lint:** Run `mix credo --strict` and fix all reported issues.
6.  **Document:** Update `TASKS.md` (mark task complete), `PERFORMANCE_OPTIMIZATIONS.md` (if relevant), and any affected module/function documentation (`@moduledoc`, `@doc`). Write clear, concise documentation.
7.  **Commit:** Commit changes frequently with clear, descriptive messages following conventional commit guidelines (e.g., `feat: Add read_concurrency to ETS tables`, `fix: Correct calculation in PageRank`, `test: Add tests for DisjointSet module`, `refactor: Extract ETS table management logic`).
8.  **Pull Request:** Open a Pull Request (PR) to the `main` (or `develop`) branch. Ensure the PR description clearly explains the changes, links to this plan/phase, and includes any benchmark results.
9.  **Review & Merge:** Participate in the code review process, address feedback promptly, and merge upon approval.
10. **Update `TASKS.md`:** Mark the completed task with ✅.

---

### Phase 1: Foundational Improvements & Utility Testing (~2-3 days)

**Goal:** Implement immediate ETS performance improvements, fix code quality issues, and ensure core utility modules are fully tested.

**Tasks:**

1.  **✅ ETS Concurrency Flags:**
    *   **Task:** Locate the function responsible for creating ETS tables (likely in `GraphOS.Store.Adapter.ETS`). Modify the `options` list passed to `:ets.new/2` for the primary `_nodes` and `_edges` tables to include `:read_concurrency` and `:write_concurrency`, both set to `true`.
    *   **Testing:** Run `mix test`. Verify all existing tests continue to pass. No new tests needed specifically for this, but monitor for any unexpected concurrency issues in later phases.
    *   **Success Criteria:** Code change implemented correctly; all existing tests pass.
    *   **Documentation:** Add a bullet point under "ETS Table Optimizations" in `PERFORMANCE_OPTIMIZATIONS.md` explaining the use and benefit of these flags.
2.  **✅ Match Specification for `all/3` Filtering:**
    *   **Task:** Identify the function in `GraphOS.Store.Adapter.ETS` that handles retrieving all records of a given type (e.g., `do_get_all/3`). Currently, it likely retrieves all ETS records and then filters out deleted ones using `Enum.filter` or `Enum.reduce`. Replace this post-fetch filtering with an `:ets.select/2` call. Construct a match specification (`match_spec`) that matches tuples `{_id, record}` where the `record.metadata.deleted` field is `false`.
        *   *Example Match Spec Outline:* `[{{:'_', :'$1'}, [{:'==', {:map_get, :deleted, {:map_get, :metadata, :'$1'}}, false}], [:'$1']}]` (Verify syntax and structure carefully).
    *   **Testing:**
        *   Run `mix test` to ensure existing tests relying on `Store.all/3` (or the underlying adapter function) still pass.
        *   *Add Test:* In `test/store/adapter/ets_test.exs`, create a new test case:
            1. Insert several nodes/edges.
            2. Mark at least one as deleted using `Store.delete/3`.
            3. Call `Store.all/3` for that type.
            4. Assert that the returned list *only* contains the non-deleted records and *does not* contain the deleted ones.
        *   *Benchmark (Optional but Recommended):* If possible, manually time the `Store.all/3` call on a store with many records, a significant portion of which are marked deleted, both before and after the change.
    *   **Success Criteria:** Existing tests pass; new test specifically verifying deleted filtering passes; benchmark shows performance improvement (or at least no regression) when deleted items exist.
    *   **Documentation:** Update the "Query Optimization" section in `PERFORMANCE_OPTIMIZATIONS.md` to accurately describe using match specs for filtering deleted records in `all/3`.
3.  **✅ Predicate Naming Convention:**
    *   **Task:** Perform a project-wide search for function names starting with `is_` (e.g., `is_allowed?`, `is_valid_type?`). For functions that return a simple boolean value, rename them to end with a `?` (e.g., `allowed?`, `valid_type?`). Carefully update all places where these functions are called. Pay close attention to `Access` modules.
    *   **Testing:** Run `mix test`. Ensure all tests pass after renaming and updating call sites.
    *   **Success Criteria:** Renaming completed; all tests pass.
    *   **Documentation:** No specific doc changes needed, but this improves code readability and aligns with Elixir conventions. Addresses issue noted in `TASKS.md` analysis.
4.  **✅ Test `Algorithm.Weights`:**
    *   **Task:** Open `test/store/algorithm/weights_test.exs`. Add new `test` blocks to cover the following scenarios for each function:
        *   `get_edge_weight/3`: Test with `nil` edge, edge with weight in `data`, edge without weight in `data` (using default), edge with non-numeric weight (ensure default is used or error handled gracefully, depending on desired behavior).
        *   `normalize_weights/1`: Test with empty map, map with one item, map with all identical values, map with positive values, map with negative values, map with mixed values. Verify results are within [0, 1] range.
        *   `invert_weights/3`: Test `:reciprocal` method (handle zero/negative values), test `:subtract` method (with and without explicit `max_value`). Test with different ranges of input weights.
    *   **Testing:** Run `mix test --cover`. Check the coverage report for `lib/store/algorithm/weights.ex`.
    *   **Success Criteria:** Coverage for `GraphOS.Store.Algorithm.Weights` increases significantly (target > 90%). All added tests pass.
5.  **✅ Test `Algorithm.Utils.DisjointSet`:**
    *   **Task:** Create the file `test/store/algorithm/utils/disjoint_set_test.exs`. Add `test` blocks covering:
        *   `new/1`: Creating with an empty list and a list of IDs.
        *   `find/2`: Finding elements in their own set initially, finding elements after unions.
        *   `union/3`: Unioning two separate sets, unioning sets where one element is already the root, unioning elements already in the same set (should be idempotent). Verify the structure after unions using `find/2`.
        *   `get_sets/1`: Getting sets after various unions, ensuring all initial elements are present in the final sets. Test with empty initial set.
    *   **Testing:** Run `mix test --cover`. Check coverage for `lib/store/algorithm/utils/disjoint_set.ex`.
    *   **Success Criteria:** Coverage for `GraphOS.Store.Algorithm.Utils.DisjointSet` is high (target > 90%). All added tests pass.

---

### Phase 2: Core Stability - Adapter Refactor & Algorithm Testing (~3-5 days)

**Goal:** Improve the architecture of the ETS adapter for better maintainability and ensure core graph algorithms are tested and reliable.

**Tasks:**

1.  **✅ Refactor `Adapter.ETS` into Modules:**
    *   **Task:**
        1. Create a new directory: `lib/store/adapter/ets/`.
        2. Create the following new module files within that directory:
            *   `table_manager.ex`
            *   `crud.ex`
            *   `index_manager.ex`
            *   `cache_manager.ex` (Initially, this might just contain comments or basic structure if caching isn't moved yet).
        3. Systematically move logic from the large `lib/store/adapter/ets.ex` file into the appropriate new modules:
            *   `TableManager`: Functions related to `:ets.new`, table naming conventions, checking table existence.
            *   `CRUD`: Functions implementing the core `GraphOS.Store.Adapter` behaviour callbacks (`insert`, `get`, `update`, `delete`, `all`, `batch_insert`, etc.). These functions might *call* functions in `TableManager` or `IndexManager`.
            *   `IndexManager`: Functions related to creating, managing, updating, and querying the secondary ETS tables used for indexing (e.g., `_edges_by_source`, `_edges_by_target`, `_edges_by_type`, `_edge_source_type_idx`). The CRUD functions will call these when inserting/updating/deleting edges.
        4. Modify the main `lib/store/adapter/ets.ex` file to:
            *   Act primarily as a facade.
            *   Implement the `GraphOS.Store.Adapter` behaviour callbacks.
            *   Delegate the actual work by calling functions in the new `TableManager`, `CRUD`, `IndexManager` modules. Keep minimal logic here. Use `alias` for the internal modules.
    *   **Testing:**
        *   Run `mix test`. All tests in `test/store/adapter/ets_test.exs` *must* pass after this significant refactoring.
        *   Review `ets_test.exs`. If tests were tightly coupled to the internal structure of the old `ets.ex`, they may need refactoring to test through the public adapter interface or the new module interfaces where appropriate.
    *   **Success Criteria:** Code is logically separated into the new modules; `lib/store/adapter/ets.ex` is significantly smaller and acts as a facade; all tests in `ets_test.exs` pass without modification (ideal) or after necessary test refactoring.
    *   **Documentation:** Add `@moduledoc` to each new module explaining its responsibility. Update comments within the code to reflect the new structure.
2.  **✅ Test `Algorithm.PageRank`:**
    *   **Task:** Create `test/store/algorithm/page_rank_test.exs`.
        1. Define a small, simple graph structure (e.g., 3-4 nodes, a few edges) within the test setup. Use known weights or assume default weight 1.
        2. Manually calculate the expected PageRank scores after 1-2 iterations for this known graph (or use an online calculator/library result for comparison).
        3. Add a test that sets up this graph in a test store, runs `GraphOS.Store.Algorithm.PageRank.execute/1` (or `Store.traverse/3`), and asserts that the returned scores are approximately equal (`assert_in_delta/3`) to the expected scores.
        4. Add tests to verify the `:iterations` option: run with more iterations and check if scores change/converge.
        5. Add tests for the `:damping` factor option.
        6. Add a test case for a graph with nodes having no outgoing links.
        7. Add a test case using weighted edges and the `:weight_property` option.
    *   **Testing:** Implement the test cases described above. Run `mix test --cover`.
    *   **Success Criteria:** Tests pass, demonstrating correct PageRank calculation for simple weighted/unweighted graphs and correct handling of options. Coverage increases.
3.  **✅ Test `Algorithm.ConnectedComponents`:**
    *   **Task:** Create `test/store/algorithm/connected_components_test.exs`.
        1. Test Case 1: Graph with no edges (each node is its own component).
        2. Test Case 2: Fully connected graph (one component containing all nodes).
        3. Test Case 3: Graph with multiple distinct components (e.g., nodes 1-3 connected, nodes 4-5 connected). Verify the output is a list containing lists of node IDs for each component.
        4. Test Case 4 (If applicable): Test with `:edge_type` filter, ensuring components are found based only on edges of that type.
    *   **Testing:** Implement test cases covering these graph structures. Ensure the output format (list of lists of node IDs) is asserted correctly, potentially sorting lists for consistent comparison.
    *   **Success Criteria:** Tests pass, correctly identifying components in various scenarios. Coverage increases.
4.  **✅ Test `Algorithm.MinimumSpanningTree`:**
    *   **Task:** Create `test/store/algorithm/minimum_spanning_tree_test.exs`.
        1. Define a small, weighted graph (e.g., 4-5 nodes) where the MST edges and total weight are known.
        2. Add a test that sets up this graph, runs `GraphOS.Store.Algorithm.MinimumSpanningTree.execute/1`, and asserts:
            *   The correct set of `Edge` structs (or their IDs) is returned.
            *   The correct total weight is returned.
        3. Add a test using the `:weight_property` option with a custom weight field in edge data.
        4. Add a test using the `:default_weight` option for edges missing the weight property.
        5. Add a test with `prefer_lower_weights: false` to find the *Maximum* Spanning Tree and verify the result.
        6. Add a test for a disconnected graph (verify it finds MST for each component or handles it as documented).
    *   **Testing:** Implement tests covering core logic, options, and edge cases. Sort edge lists before assertion for consistency.
    *   **Success Criteria:** Tests pass, correctly identifying MST edges and total weight in various scenarios. Coverage increases.

---

### Phase 3: Core Functionality - Basic Persistence & Access Control Testing (~4-6 days)

**Goal:** Introduce basic disk persistence to prevent data loss on restarts and begin testing the critical, currently untested access control modules.

**Tasks:**

1.  **✅ Implement Snapshot Persistence:**
    *   **Task:**
        1.  Modify `GraphOS.Store.start_link/1` to accept a `:persistence_opts` keyword list, potentially including `:snapshot_dir` and `:snapshot_on_stop` (boolean).
        2.  In the `ETS.TableManager` (or potentially a new `ETS.PersistenceManager` module):
            *   Implement `load_snapshot(store_name, snapshot_dir)`: On store startup, check for existing snapshot files (e.g., `#{store_name}_nodes.ets`, `#{store_name}_edges.ets`, index files) in the specified directory. If found, use `:ets.file2tab/2` to load them into newly created ETS tables. Handle errors gracefully (e.g., file not found, corrupted file).
            *   Implement `save_snapshot(store_name, snapshot_dir)`: Iterate through the relevant ETS tables (nodes, edges, indices) managed by the store and use `:ets.tab2file/2` to save each to a file in the snapshot directory.
        3.  Modify the `GraphOS.Store` GenServer's `init/1` function to call `load_snapshot` if configured.
        4.  Modify the `GraphOS.Store` GenServer's `terminate/2` function to call `save_snapshot` if `:snapshot_on_stop` is true.
        5.  (Optional) Add a `Store.save_snapshot(store_name)` function/command to trigger snapshots manually.
    *   **Testing:**
        *   Add tests (likely integration style in `store_test.exs` or a new `persistence_test.exs`):
            1. Start a store *with* snapshotting configured.
            2. Insert data (nodes, edges).
            3. Stop the store. Verify snapshot files exist in the expected directory.
            4. Start the *same* store again.
            5. Query the store and verify the data inserted in step 2 is present.
            6. Test error handling (e.g., starting with a non-existent snapshot directory).
    *   **Success Criteria:** Data is correctly saved on stop and reloaded on start; tests pass.
    *   **Documentation:** Add a "Persistence" section to `PERFORMANCE_OPTIMIZATIONS.md` (or a new `PERSISTENCE.md`) detailing the snapshot strategy, configuration options, and file locations. Document relevant functions.
2.  **✅ Implement Write-Ahead Log (WAL) Persistence:**
    *   **Task:** (Builds on Snapshotting)
        1.  Update `:persistence_opts` to include `:wal_dir`.
        2.  In the `ETS.CRUD` module (or `ETS.PersistenceManager`), before performing the actual ETS operation (`:ets.insert`, `:ets.delete`, `:ets.insert` for update) for any write operation (`insert`, `update`, `delete`, `batch_*`), *first* serialize the operation and its data (e.g., using `:erlang.term_to_binary/1`) and append it to a WAL file (e.g., `#{store_name}.wal`) in the `wal_dir`. Use `:file.open/2` with `[:append, :binary]` and ensure the file is closed properly (or use a dedicated file process).
        3.  Modify the `load_snapshot` logic: After loading from snapshot files, implement `replay_wal(store_name, wal_dir, snapshot_timestamp)`:
            *   Read the WAL file from the beginning (or potentially from an offset if snapshots store a timestamp/log sequence number).
            *   Deserialize each entry (`:erlang.binary_to_term/1`).
            *   Re-apply the logged operation (insert/update/delete) directly to the ETS tables.
            *   Handle potential errors during replay.
        4.  Implement WAL management: Decide on a strategy for WAL file rotation or truncation (e.g., start a new WAL file after each successful snapshot).
    *   **Testing:**
        *   Add tests simulating crashes:
            1. Start store with WAL enabled.
            2. Insert/update/delete some data.
            3. Simulate crash (e.g., stop store *without* calling `terminate/2` or saving snapshot).
            4. Restart the store.
            5. Verify data changes from step 2 are present (replayed from WAL).
        *   Measure write latency increase due to WAL append.
    *   **Success Criteria:** Data is recovered correctly after simulated crashes; tests pass; write latency impact is understood and acceptable.
    *   **Documentation:** Update the "Persistence" section detailing the WAL strategy, configuration, recovery process, and latency impact.
3.  **✅ Test `Access.OperationGuard`:**
    *   **Task:** Open `test/access/operation_guard_test.exs`. Review the existing tests and the skipped test.
        1.  Ensure tests cover `check_permission/4`: test cases where permission is granted, denied, and where the policy/permission doesn't exist. Mock `GraphOS.Access.Permission.check/1` if needed, or set up actual policies/permissions in the test store.
        2.  Implement the skipped test for `before_operation` and `after_operation` hooks. Create simple hook modules that modify data or return specific values/errors, configure the `OperationGuard` to use them, and verify the hooks are executed and their effects are applied correctly (or errors handled).
    *   **Testing:** Implement/unskip tests covering core permission checks and hook execution. Run `mix test --cover`.
    *   **Success Criteria:** All tests in `operation_guard_test.exs` pass, including the previously skipped one. Coverage for `GraphOS.Access.OperationGuard` increases significantly.
4.  **✅ Test `Access.Policy` & `Access.Permission` (Basic):**
    *   **Task:** Create `test/access/policy_permission_test.exs` (or add to `access_test.exs`). Focus on the interaction:
        1.  Create a Policy (assuming `Policy` module provides functions like `create/1`, `get/1`).
        2.  Grant Permissions using `Permission.grant/3` (or similar) linked to that Policy, an Actor/Group, and a Resource/Action.
        3.  Verify permissions using `Permission.check/4` (or similar) for different actors/resources/actions (granted and denied cases).
        4.  Test revoking permissions (`Permission.revoke/3`?) and verify subsequent checks fail.
        5.  Test deleting a Policy and verify associated permissions are handled (e.g., checks fail).
    *   **Testing:** Implement integration tests covering the lifecycle of creating policies, granting, checking, and revoking permissions.
    *   **Success Criteria:** Tests pass, demonstrating the basic workflow of policy and permission management. Coverage for `Access.Policy` and `Access.Permission` increases.

---

### Phase 4: Advanced Performance, Features & Testing (~ পরবর্তী রিলিজ চক্র / Next Release Cycle)

**Goal:** Implement more advanced performance optimizations, add new features like A*, and complete testing of Access Control modules.

**Tasks:**

1.  **⏳ Configurable Property Indexing:** Enhance `ETS.IndexManager` to support indexing arbitrary `data` fields, configured at store startup. Add associated query functions and tests.
2.  **⏳ Generalize Caching (`CacheManager`):** Move remaining caching logic (if any) to `ETS.CacheManager`. Implement LRU/LFU eviction strategy. Ensure robust cache invalidation for all relevant mutations. Add tests for eviction and invalidation.
3.  **⏳ Implement A\* Algorithm:** Create `lib/store/algorithm/a_star.ex` and `test/store/algorithm/a_star_test.exs`. Implement the algorithm accepting a heuristic function. Test with admissible and non-admissible heuristics.
4.  **⏳ Test Remaining Access Modules (`Actor`, `Scope`, `Group`, `Membership`):** Create dedicated test files (e.g., `actor_test.exs`, `group_test.exs`) or expand existing ones (`actor_scope_test.exs`, `group_membership_test.exs`). Test creation, validation, retrieval, deletion, and relationships (e.g., adding members to groups, checking scope validity) for each module according to its specific responsibilities. Ensure high test coverage.
5.  **⏳ Parallel Algorithm Execution:** Identify computationally intensive loops within key algorithms (e.g., BFS, PageRank, potentially parts of MST/ConnectedComponents on very large graphs) and investigate using `Task.async_stream` for parallelization where appropriate. Add benchmarks to prove benefit outweighs overhead. Make parallelism configurable (e.g., via an `opts` flag).
6.  **⏳ Query Planner (Basic):** Implement a simple query planner within the ETS adapter. For queries with multiple filters (e.g., source node AND edge type), the planner should estimate the cost of using different available indexes (source index, type index, composite index) based on :ets.info counts or pre-calculated statistics and choose the likely fastest approach. Start with simple cost estimation (e.g., smallest estimated result set).
7.  **⏳ Further Code Quality Improvements:** Address remaining medium/low priority items from the initial `TASKS.md` code analysis (e.g., refactor complex functions like `ShortestPath.get_neighbors`, improve `with` statements, reduce negative conditions).

---
