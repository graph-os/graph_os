# GraphOS Action Execution System

This document describes the `GraphOS.Action` system, the standardized approach for defining and executing operations on GraphOS graph nodes (entities).

## Overview

The `GraphOS.Action` system provides a centralized mechanism for handling the execution lifecycle of operations requested on graph nodes. It integrates argument validation, asynchronous execution management, authorization via `GraphOS.Access`, and standardized interaction patterns.

Actions are initiated within the context of an authenticated `GraphOS.Conn` process, typically by calling an `execute/4` function (including `store_ref`) on the module representing the target graph node type (e.g., `GraphOS.Core.FileSystem.File`). This function resolves the target node, determines the operation and scope ID, and then calls the `GraphOS.Action` service to orchestrate the execution.

## Principles

1.  **Node-Centric Execution:** Actions are operations performed *on* specific graph nodes (entities). Execution is dispatched via an `execute/4` function (including `store_ref`) within the node's module, which is responsible for resolving the target node entity and the relevant `scope_id` for authorization.
2.  **Centralized Orchestration:** The `GraphOS.Action` module provides a central service (`request_execution`) for handling validation, authorization (using a pre-resolved `scope_id`), and managing the asynchronous execution lifecycle via `GraphOS.Action.Runner` processes.
3.  **Metadata-Driven:** Action capabilities (input requirements for specific operations) are defined declaratively using metadata (e.g., `@action_meta`).
4.  **Discoverable:** Available actions/operations and their metadata can potentially be registered and queried (details TBD).
5.  **Asynchronous by Default:** Actions are executed asynchronously. A `wait` option allows callers to synchronously await completion up to a timeout.
6.  **Integrated Security:** Authorization (`GraphOS.Access.has_permission_in_store?`) is performed by `GraphOS.Action.request_execution` using the caller's `Actor` ID (from `GraphOS.Conn`), the `store_ref`, and the `scope_id` provided by the calling `execute/4` function.
7.  **Protocol Agnostic:** The core execution logic is independent of the specific protocol (`GraphOS.Protocol` adapter) that initiated the request via `GraphOS.Conn`.

## Implementation

### Defining Actions in Node Modules

Actions are handled within the module representing the graph node type (e.g., `GraphOS.Core.FileSystem.File`). The primary entry point is typically an `execute/4` function which resolves the node, determines the scope ID, and delegates to `GraphOS.Action`. Metadata for specific operations can be attached using `@action_meta`.

```elixir
# Example: apps/graph_os_core/lib/graph_os/core/file_system/file.ex
defmodule GraphOS.Core.FileSystem.File do
  use GraphOS.Entity.Node # Make this module a graph node entity

  alias GraphOS.Conn
  alias GraphOS.Core.FileSystem # Parent Graph module for queries
  require Logger

  # Allow injecting the graph module dependency for testing
  @file_system_graph_module Application.compile_env(:graph_os_core, __MODULE__, file_system_graph_module: FileSystem)

  require GraphOS.Action.Behaviour
  Module.register_attribute(__MODULE__, :action_meta, accumulate: true, persist: true)

  # --- Action Metadata ---
  @action_meta {:read, %{
    description: "Reads the content of this file.",
    input_schema: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path (target identifier)"}
        # No other args needed for read
      },
      "required" => ["path"] # Path needed if node not resolved yet
    }
  }}
  @action_meta {:write, %{
    description: "Writes content to this file.",
    input_schema: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path (target identifier)"},
        "content" => %{"type" => "string", "description" => "Content to write"}
      },
      "required" => ["path", "content"]
    }
  }}

  # --- Execution Entry Point ---
  def execute(store_ref, conn, payload, opts \\ []) do
    # 1. Resolve Node, Scope ID and Extract Operation Details
    case resolve_node_and_operation(store_ref, conn, payload) do
      {:ok, _node, scope_id, operation_atom, operation_args, meta} ->
        # 2. Delegate to Action Service, passing resolved scope_id
        GraphOS.Action.request_execution(store_ref, conn, scope_id, __MODULE__, operation_atom, operation_args, meta, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Node Resolution & Scope ID Logic (Example) ---
  # Returns {:ok, node, scope_id, op_atom, op_args, meta} | {:error, reason}
  defp resolve_node_and_operation(store_ref, conn, {%__MODULE__{} = node, scope_id, operation_atom, operation_args})
       when is_binary(scope_id) and is_atom(operation_atom) do
     # Node and scope_id explicitly provided
     meta = get_operation_meta(operation_atom)
     {:ok, node, scope_id, operation_atom, operation_args, meta}
  end
  defp resolve_node_and_operation(store_ref, conn, %{"path" => path, "action" => op_string} = payload) do
     # Resolve node by path, derive scope_id from path
     args = Map.get(payload, "args", %{})
     with {:ok, node} <- apply(@file_system_graph_module, :get_by_path, [store_ref, conn, path]),
          {:ok, operation_atom} <- parse_operation_atom(op_string) do
        meta = get_operation_meta(operation_atom)
        scope_id = "file-scope-#{path |> Path.basename() |> String.replace(~r/[^a-zA-Z0-9]/, "-")}" # Example scope derivation
        operation_args = Map.put_new(args, "path", path)
        {:ok, node, scope_id, operation_atom, operation_args, meta}
     else
       err -> err
     end
  end
   # ... other resolve clauses for ID, etc. ...
  defp resolve_node_and_operation(_store_ref, _conn, _payload), do: {:error, :invalid_payload_format}

  defp get_operation_meta(:read), do: @read_meta
  defp get_operation_meta(:write), do: @write_meta
  defp get_operation_meta(_), do: %{}

  defp parse_operation_atom(s) when is_binary(s), do: String.to_existing_atom(s) |> (&({:ok, &1})).() rescue ArgumentError -> :error
  defp parse_operation_atom(_), do: :error

  # --- Internal Implementation Functions (called by Runner) ---
   @doc false
  def do_read(args) do # Public function
    path = Map.fetch!(args, "path")
    Logger.debug("Executing do_read for path: #{path}")
    File.read(path)
  end

  @doc false
  def do_write(args) do
    path = Map.fetch!(args, "path")
    content = Map.fetch!(args, "content")
    # Actual file writing logic with error handling
    File.write(path, content)
  end
end
```

**`@action_meta` Keys (Associated with Operation Atom):**

*   `:input_schema` (Required): A map representing the JSON Schema for the `args` map passed to `handle_action/4` for this specific operation. Used for validation by `GraphOS.Action.request_execution`.
*   `:description` (Optional): A string describing the operation's purpose.
*   *(Optional)* `:scope_deriver`: No longer used by `GraphOS.Action`. Scope resolution happens in the node module's `execute/4` function before calling `request_execution`.

### Action Registration

Registration mechanisms (TBD) would likely focus on making the node's `execute/4` function or the specific operations it supports discoverable, potentially storing the associated `@action_meta` in the `GraphOS.Action.Registry`.

### `GraphOS.Action` Runtime (Core Module)

Located within the `graph_os_core` application, this provides the central orchestration service.

*   **`GraphOS.Action.Supervisor`:** Manages `GraphOS.Action.Runner` processes using `DynamicSupervisor`.
*   **`GraphOS.Action.Runner` (GenServer):** Handles the execution of a single action instance. It receives the target module, operation atom, and arguments. It calls the corresponding `do_operation` function (e.g., `TargetModule.do_read(args)`) and manages the execution state (pending, running, completed, failed) and results/errors.
*   **`GraphOS.Action` API:**
    *   `request_execution(store_ref \\ :default, conn, scope_id, target_module, operation_atom, args, meta, opts \\ [])`:
        1.  Validates `args` against `meta[:input_schema]`.
        2.  Authorizes `conn.actor_id` against the provided `scope_id` using `GraphOS.Access.has_permission_in_store?(store_ref, scope_id, actor_id, :execute)`.
        3.  If authorized, starts a `GraphOS.Action.Runner` via the `Supervisor`, passing `target_module`, `operation_atom`, and `args`.
        4.  Handles the `opts[:wait]` logic:
            *   If `wait > 0`, attempts to synchronously get the result from the `Runner` within the timeout using `Runner.get_status_sync/3`. Returns `{:ok, status_map}` on completion/failure within timeout, or `{:ok, execution_id}` on timeout.
            *   If `wait <= 0`, returns `{:ok, execution_id}` immediately after starting the runner.
        5.  Returns `{:error, reason}` if validation or authorization fails, or if the runner fails to start.
    *   `get_status(execution_id)`: Looks up the runner `pid` via `PidStore` and queries the `Runner` GenServer for its current state, result, or error. Useful for polling actions that didn't complete within the `wait` timeout.
    *   *(Potentially)* `list_actions(...)`: Queries the `Action.Registry` for discoverable actions/operations.

### Security Integration (`GraphOS.Access`)

*   Execution of any action requires the caller (`conn.actor_id`) to have the standard `:execute` permission on the target resource's relevant scope.
*   The target resource's scope ID (`scope_id`) is determined by the node module's `execute/4` function (e.g., derived from path, looked up via node properties, or passed explicitly) *before* calling `GraphOS.Action.request_execution`.
*   The permission check (`GraphOS.Access.has_permission_in_store?(store_ref, scope_id, actor_id, :execute)`) is performed by `GraphOS.Action.request_execution` using the provided `scope_id` and `store_ref`. This `scope_id` must correspond to a manageable scope within the `GraphOS.Access` policy graph.
*   `GraphOS.Access` global permission defaults are respected.

## Benefits

*   Clear association of actions with the graph nodes they operate on.
*   Leverages `GraphOS.Conn` and `Actor` context for initiation and authorization.
*   Centralized orchestration (`GraphOS.Action`) for validation, security, and async lifecycle management.
*   Standardized metadata (`@action_meta`) for input validation and description.
*   Flexible asynchronous execution with optional synchronous waiting (`wait` option).
*   Integrates cleanly with `GraphOS.Access` for permission checks against target resources.

## Future Enhancements

*   Action pipelines/workflows.
*   Middleware for action execution.
*   Automatic documentation generation from metadata.
