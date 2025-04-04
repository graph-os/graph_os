# GraphOS.Protocol Plan

**Note on Structure (May 2025):** The project has been refactored from an Elixir umbrella structure to a standard dependency chain model (`graph_os_store` -> `graph_os_core` -> `graph_os_protocol`). This plan assumes the standalone application structure.

**Depends On:** `graph_os_core`, `tmux`, `mcp` (via path dependencies in `mix.exs`)

**Goal:** Define and serve the primary external communication interface (likely JSON-RPC + MCP) for AI agents, ensuring secure and controlled access to `graph_os_core` functionalities.

**General Workflow for Each Phase/Major Task:**

1.  **Create Branch:** `git checkout -b feature/protocol-phaseX-<short-description>`
2.  **Implement:** Code changes adhering to GraphOS standards.
3.  **Test:** Write unit/integration tests. Ensure **all** tests pass (`mix test`). Aim for high coverage.
4.  **Lint:** Run `mix credo --strict` and fix issues.
5.  **Document:** Update this `PLAN.md` (mark task complete), relevant module/function docs (`@moduledoc`, `@doc`), API schemas, and potentially the top-level `README.md`.
6.  **Commit:** Use conventional commit messages.
7.  **Pull Request:** Open PR to the main branch, explaining changes and linking to this plan.
8.  **Review & Merge:** Address feedback and merge upon approval.

---

## Phase 1: Setup & Basic JSON-RPC (~3-5 days)

**Goal:** Establish the protocol application structure, define the initial JSON-RPC schema, and implement a basic endpoint capable of handling simple requests.

**Tasks:**

1.  **✅ Application Setup:**
    - **Task:** Ensure `graph_os_protocol` is set up as a standard Elixir application with necessary dependencies (e.g., JSON library, potentially Cowboy or Plug for endpoint). Define application structure (`lib/graph_os_protocol/`, `test/`, etc.). Add basic supervision tree in `application.ex`.
    - **Testing:** Basic application compilation (`mix compile`) and test setup (`mix test` runs successfully, even if no tests exist yet).
    - **Success Criteria:** Application structure created; compiles successfully; basic supervision tree defined.
    - **Documentation:** Create `README.md` for `graph_os_protocol` outlining its purpose and basic setup.
2.  **✅ Define Initial JSON-RPC Schema:**
    - **Task:** Define the JSON-RPC 2.0 structure for initial `graph_os_core` actions, focusing on read-only `FileSystem` operations (`list_directory`, `read_file`, `get_info`). Specify method names, parameters (including how `actor_id` will be conveyed initially - perhaps implicitly via connection state later, but maybe explicitly in early tests), and expected success/error response formats.
    - **Testing:** N/A (schema definition). Documented examples serve as validation.
    - **Success Criteria:** Clear, documented JSON-RPC schema for initial methods.
    - **Documentation:** Create `SCHEMA.md` (or similar) detailing the JSON-RPC methods, parameters, and responses. Include examples.
3.  **✅ Implement Basic JSON-RPC Endpoint:**
    - **Task:** Implement a basic HTTP endpoint (e.g., using Plug/Cowboy or within Phoenix if `graph_os_ui` is the host) that accepts POST requests, parses JSON-RPC requests, identifies the method, but initially returns mock/stubbed responses (e.g., `{:ok, \"Not implemented yet\"}`). Handle basic JSON parsing errors.
    - **Testing:** Write integration tests that send valid/invalid JSON-RPC requests to the endpoint and verify basic parsing, method routing (even to stubs), and error handling for malformed requests.
    - **Success Criteria:** Endpoint receives requests, parses JSON-RPC, routes methods to stubs, handles basic errors.
    - **Documentation:** Document the endpoint path and basic usage in the `README.md`.
4.  **✅ Establish `Conn` Association (Placeholder):**
    - **Task:** Define the _mechanism_ by which an incoming request will eventually be associated with a `GraphOS.Conn` process and its corresponding `actor_id`. Initially, this might be a placeholder (e.g., assuming a hardcoded `actor_id` for testing, or requiring an `actor_id` parameter in the JSON-RPC call itself). The key is to design how the protocol layer will get the necessary `actor_id` to pass to `graph_os_core`.
    - **Testing:** N/A (design/placeholder step).
    - **Success Criteria:** A clear strategy (even if temporary) for obtaining `actor_id` per request is decided and documented.
    - **Documentation:** Document the chosen initial approach for associating requests with actors in the protocol layer design notes or `README.md`.
5.  **✅ Refactor Protocol Modules (May 2025):**
    - **Task:** Refactored `plug.ex`, `jsonrpc.ex`, `grpc.ex`, and `schema.ex` to remove dependencies on non-existent helper modules (`GraphOS.Adapter.*`) and incorrect `Protobuf.*` functions. Introduced usage of `GraphOS.Core.Context` struct. Corrected `GraphOS.Store.Adapter` behaviour usage.
    - **Testing:** Verified compilation after changes. Further testing needed.
    - **Success Criteria:** Modules compile; major undefined function warnings resolved.
    - **Documentation:** Code comments added; this plan updated.

---

## Phase 2: Core Integration - Read Operations (~4-6 days)

**Goal:** Connect the JSON-RPC endpoint to `graph_os_core` functions for read-only operations, ensuring proper authorization checks are triggered.

**Depends On:** `graph_os_core` Phase 1 & 2 completed.

**Tasks:**

1.  **✅ Implement `FileSystem` Read Method Handlers:**
    - **Task:** Implement the actual logic for the JSON-RPC methods defined in Phase 1 (`list_directory`, `read_file`, `get_info`).
      - Retrieve the `actor_id` based on the strategy from Phase 1, Task 4.
      - Call the corresponding functions in `GraphOS.Core.FileSystem` (e.g., `FileSystem.list_directory(actor_id, path_param)`).
      - Translate the results (`{:ok, data}` or `{:error, reason}`) from `graph_os_core` into the correct JSON-RPC success or error response format (defined in `SCHEMA.md`). Handle potential exceptions from the core layer gracefully.
    - **Testing:** Write integration tests that:
      - Send valid JSON-RPC requests for each read method.
      - Mock the `GraphOS.Core.FileSystem` calls to return expected success/error tuples.
      - Verify the endpoint returns the correctly formatted JSON-RPC success/error response.
      - Add tests specifically mocking authorization failures from the core layer (e.g., core returns `{:error, :unauthorized}`) and ensure the protocol layer translates this to an appropriate JSON-RPC error.
    - **Success Criteria:** Read methods correctly call `graph_os_core`, handle responses/errors, and format JSON-RPC output according to schema. Authorization errors are handled.
    - **Documentation:** Update `SCHEMA.md` with any refinements based on implementation. Add notes on error code mappings if specific ones are used.
2.  **✅ Implement `SystemCommand.execute` Read-Only Handler (Optional but Recommended):**
    - **Task:** Implement the handler for `SystemCommand.execute` but _initially restrict it_ (e.g., via configuration or hardcoding) to only allow known safe, read-only commands (like `echo`, `ls`, `pwd`). This allows testing the flow without enabling potentially dangerous commands yet.
      - Retrieve `actor_id`.
      - Call `GraphOS.Core.SystemCommand.execute(actor_id, command_param)`. **Crucially, rely on `graph_os_core` to perform the actual permission check based on the command.**
      - Translate result/error to JSON-RPC.
    - **Testing:** Integration tests similar to Task 1, sending allowed read-only commands and verifying successful execution and response formatting. Test sending a disallowed command (even if safe) and verify the permission check (mocked in core or real if core scopes are set up) leads to a JSON-RPC error.
    - **Success Criteria:** Handler executes whitelisted safe commands via `graph_os_core`, translates results, and correctly handles permission errors from the core layer.
    - **Documentation:** Document the initial read-only limitation for the `execute` method.

---

## Phase 3: Core Integration - Write Operations & MCP (~5-7 days)

**Goal:** Enable write operations and potentially introduce the MCP interface.

**Depends On:** `graph_os_core` Phase 4 (`FileSystem` Write Ops) completed.

**Tasks:**

1.  **⏳ Implement `FileSystem` Write Method Handlers:**
    - **Task:** Implement handlers for `FileSystem` write operations (e.g., `write_file`, `delete_file`) as defined in the JSON-RPC schema.
      - Retrieve `actor_id`.
      - Call corresponding `GraphOS.Core.FileSystem` functions.
      - Translate results/errors to JSON-RPC.
    - **Testing:** Integration tests mocking core functions for success/error cases, including authorization failures. Verify correct JSON-RPC formatting.
    - **Success Criteria:** Write methods correctly call `graph_os_core`, handle responses/errors, format JSON-RPC output.
2.  **⏳ Enable Full `SystemCommand.execute` Handler:**
    - **Task:** Remove the read-only restriction from the `execute` handler (if implemented in Phase 2). Ensure it passes the command string directly to `graph_os_core`, relying entirely on the core layer's authorization and sanitization.
    - **Testing:** Add integration tests attempting various commands (safe and potentially unsafe) and verify that the outcome depends solely on the permissions/scopes defined in `graph_os_core`/`graph_os_access`. Test commands that should succeed and commands that should be blocked by core's authorization.
    - **Success Criteria:** Handler passes commands to `graph_os_core`; outcomes align with core-level permissions.
3.  **⏳ Define MCP Integration Strategy (If Pursuing):**
    - **Task:** Decide how MCP will integrate. Will it be a separate endpoint? Will it wrap/translate JSON-RPC? Will it use the standalone `mcp` library? Define the mapping between MCP tool calls and `graph_os_core` functions/JSON-RPC methods.
    - **Testing:** N/A (Design).
    - **Success Criteria:** Clear integration strategy documented.
    - **Documentation:** Document the chosen MCP strategy.
4.  **⏳ Implement Basic MCP Server Endpoint (If Pursuing):**
    - **Task:** Implement the MCP endpoint based on the chosen strategy. Map incoming MCP tool calls to the corresponding `graph_os_core` functions (likely reusing the logic/validation from the JSON-RPC handlers), ensuring `actor_id` retrieval and permission checks occur.
    - **Testing:** Integration tests sending valid/invalid MCP requests, mocking core interactions, and verifying MCP responses/errors.
    - **Success Criteria:** MCP endpoint receives requests, calls core functions correctly (with auth checks), and returns valid MCP responses.
    - **Documentation:** Document the MCP endpoint and supported tool calls.

---

## Phase 4: Authentication & Refinements (~ Next Cycle)

**Goal:** Implement proper agent authentication at the protocol layer and refine overall protocol handling.

**Tasks:**

1.  **⏳ Implement Agent Authentication (Protocol Layer):**
    - **Task:** Design and implement a mechanism within `graph_os_protocol` for external agents to authenticate (e.g., via API keys, tokens passed in headers/requests). This layer is responsible for verifying credentials. Modify the request handling logic (e.g., within `GraphOS.Protocol.Plug` or dedicated auth plugs) to perform authentication *before* processing the request. On successful authentication, determine the corresponding `actor_id` (likely by querying `GraphOS.Access` via `graph_os_core`) and populate it in the `GraphOS.Core.Context` struct passed to subsequent layers. Remove any temporary/placeholder `actor_id` logic.
    - **Testing:** Add tests for various authentication scenarios (valid credentials, invalid credentials, missing credentials). Verify that unauthenticated requests are rejected with appropriate protocol errors (e.g., 401 Unauthorized) and that authenticated requests correctly populate the `actor_id` in the `Context`.
    - **Success Criteria:** Secure authentication mechanism implemented at the protocol boundary; unauthenticated access blocked; successful authentication provides the correct `actor_id` to the core layer via the `Context`.
2.  **⏳ Refine Error Handling & Reporting:**
    - **Task:** Standardize error codes and messages across JSON-RPC and MCP (if used). Ensure internal errors in the protocol layer or core layer are translated into meaningful, non-sensitive error responses for the agent.
    - **Testing:** Review and enhance tests to cover a wider range of error conditions and verify consistent, informative error reporting.
3.  **⏳ Optimize Performance:**
    - **Task:** Profile request handling and identify bottlenecks, especially around JSON parsing/serialization and interaction with the core layer. Implement optimizations where necessary.
    - **Testing:** Benchmark key API calls under load.

---

_(See `../PLAN.md` for overall project context)_
