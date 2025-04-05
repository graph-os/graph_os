defmodule GraphOS.Action do
  @moduledoc """
  Provides the main API for executing registered actions within GraphOS components.

  Handles action lookup, argument validation, authorization via GraphOS.Access,
  and manages asynchronous execution through GraphOS.Action.Runner processes.
  """

  alias GraphOS.Action.{Registry, Runner, Supervisor, PidStore}
  alias GraphOS.Access
  alias ExJsonSchema.Validator

  require Logger

  @doc """
  Requests and orchestrates the execution of an action on a target node.

  Invoked by the target node's `handle_action/4` function.

  1. Validates arguments against metadata schema.
  2. Determines the target scope ID.
  3. Authorizes the caller (from `conn.actor_id`) against the scope.
  4. Starts an `Action.Runner` process.
  5. Optionally waits for completion based on `opts[:wait]`.
  6. Returns `{:ok, execution_id}` (if async or timed out) or `{:ok, status_map}` (if completed within wait),
     or `{:error, reason}` on failure.
  """
  @spec request_execution(store_ref :: atom() | pid(), conn :: GraphOS.Conn.t(), scope_id :: String.t(), target_module :: module(), operation_atom :: atom(), args :: map(), meta :: map(), opts :: keyword()) ::
          {:ok, String.t() | map()} | {:error, atom() | {atom(), any()}}
  def request_execution(store_ref \\ :default, conn, scope_id, target_module, operation_atom, args, meta, opts \\ []) do
    # Assume conn struct has actor_id field
    caller_actor_id = conn.actor_id
    # store_ref is now passed positionally
    action_key = {target_module, operation_atom} # For logging/context

    with {:ok, validated_args} <- validate_args(meta[:input_schema], args, action_key),
         # Scope ID is now provided, authorize using store_ref from conn
         :ok <- authorize_action(store_ref, caller_actor_id, scope_id, action_key) do
      # Start runner and handle wait logic
      handle_runner_start(conn, target_module, operation_atom, validated_args, opts) # Pass full conn
    else
      {:error, reason} ->
        Logger.warning("[GraphOS.Action] Execution failed pre-flight check for #{inspect(action_key)} on scope '#{scope_id}': #{inspect(reason)}")
        {:error, reason}
    end
  end


  @doc """
  Retrieves the status of an ongoing or completed action execution.
  """
  @spec get_status(execution_id :: String.t()) :: {:ok, map()} | {:error, :not_found | any()}
  def get_status(execution_id) do
    case PidStore.get(execution_id) do
      nil ->
        {:error, :not_found}
      pid ->
        # Check if pid is alive before calling, handle potential race condition
        if Process.alive?(pid) do
          Runner.get_status(pid)
        else
          # Process died but wasn't cleaned up from PidStore yet
          PidStore.delete(execution_id) # Cleanup attempt
          {:error, :not_found}
        end
    end
  end

  @doc """
  Lists available actions, optionally filtered by component module.

  Returns a list of tuples: `{{module, action_name}, metadata}`
  """
  @spec list_actions(component_module :: module() | nil) :: list({{module(), atom()}, map()})
  def list_actions(component_module \\ nil) do
    Registry.list_actions(component_module)
  end

  # --- Private Helpers ---

  # Validate args against schema defined in metadata
  defp validate_args(nil, args, _action_key), do: {:ok, args} # No schema, skip validation
  defp validate_args(schema, args, action_key) do
    case Validator.validate(schema, args) do
      :ok ->
        {:ok, args}
      {:error, errors} ->
        Logger.warning("[GraphOS.Action] Argument validation failed for #{inspect(action_key)}: #{inspect(errors)}")
        {:error, {:validation_failed, errors}}
    end
  end

  # Removed determine_scope_id/3 as scope is resolved before calling request_execution

  # Authorize the action using GraphOS.Access and the specific store_ref
  defp authorize_action(store_ref, caller_actor_id, scope_id, action_key) do
    # Directly check if the actor has :execute permission on the provided scope_id
    case Access.has_permission_in_store?(store_ref, scope_id, caller_actor_id, :execute) do
      true ->
        :ok
      false ->
        Logger.warning("[GraphOS.Action] Authorization failed for caller '#{caller_actor_id}' on store '#{inspect(store_ref)}' to execute #{inspect(action_key)} on scope '#{scope_id}'. Reason: No :execute permission found.")
        {:error, :unauthorized} # Don't leak detailed reason
    end
  end

  # Start the runner process and handle the wait logic
  defp handle_runner_start(conn, target_module, operation_atom, validated_args, opts) do
    execution_id = UUID.uuid4()
    wait_timeout = Keyword.get(opts, :wait, 0) # Default wait is 0 (fully async)

    runner_opts = [
      execution_id: execution_id,
      caller_actor_id: conn.actor_id,
      target_module: target_module,
      operation_atom: operation_atom,
      args: validated_args
    ]

    case Supervisor.start_runner(runner_opts) do
      {:ok, pid} ->
        # Store the mapping
        PidStore.put(execution_id, pid)
        # TODO: Need a robust way to remove pid from store on termination.
        # Could involve monitoring pid here or having Runner notify PidStore.

        # Asynchronously trigger the execution within the runner using pid
        Runner.execute(pid)

        # Handle wait logic using pid and execution_id
        if wait_timeout > 0 do
          case Runner.get_status_sync(pid, execution_id, wait_timeout) do
            {:ok, status_map} ->
              # Cleanup PidStore if action completed/failed within wait
              if status_map.status in [:completed, :failed] do
                PidStore.delete(execution_id)
              end
              {:ok, status_map}
            {:error, :timeout} ->
              {:ok, execution_id} # Timed out, return ID
            {:error, :process_down} ->
              # Runner died during sync wait
              PidStore.delete(execution_id) # Cleanup attempt
              Logger.error("[GraphOS.Action] Runner process #{inspect(pid)} for #{execution_id} died during sync wait.")
              {:error, {:sync_wait_failed, :process_down}}
            {:error, error_reason} -> # Other errors from get_status_sync
              # Runner died or other error during sync wait
              Logger.error("[GraphOS.Action] Error during sync wait for #{execution_id}: #{inspect(error_reason)}")
              {:error, {:sync_wait_failed, error_reason}}
          end
        else
          # No wait requested, return execution ID immediately
          {:ok, execution_id}
        end

      {:error, reason} ->
        Logger.error("[GraphOS.Action] Failed to start Action Runner process for #{inspect({target_module, operation_atom})}: #{inspect(reason)}")
        {:error, :runner_start_failed}
    end
  end
end
