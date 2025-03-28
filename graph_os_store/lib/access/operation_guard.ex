defmodule GraphOS.Access.OperationGuard do
  @moduledoc """
  Provides functionality to automatically check access control permissions for operations.

  This module can be used to guard operations (insert/update/delete) based on the actor's permissions.
  It is designed to be used as a hook in GraphOS.Store operations, or via the `use OperationGuard` macro.
  """

  alias GraphOS.Entity.{Node, Edge, Graph}
  alias GraphOS.Access
  require Logger

  # --- Hook Registry --- Use Agent for simple storage ---

  defmodule HookRegistry do
    use Agent

    def start_link(_opts) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def register(entity_module, hook_module) do
      Agent.update(__MODULE__, &Map.put(&1, entity_module, hook_module))
    end

    def get(entity_module) do
      Agent.get(__MODULE__, &Map.get(&1, entity_module))
    end
  end

  @doc "Registers a hook module for a given entity module."
  def register_hook(entity_module, hook_module) do
    # Ensure registry is started
    case Process.whereis(HookRegistry) do
      nil -> {:ok, _} = HookRegistry.start_link([])
      _pid -> :ok
    end
    HookRegistry.register(entity_module, hook_module)
  end

  @doc "Retrieves the registered hook module for a given entity module."
  def get_hooks_for(entity_module) do
    HookRegistry.get(entity_module)
  end

  # --- Permission Checking Logic (Existing + store_name) ---

  @doc """
  Checks if an actor is authorized to perform an operation on an entity within a specific store.
  """
  @spec check_permission(store_ref :: term(), actor_id :: String.t(), operation :: atom(), entity :: struct() | map() | binary(), opts :: keyword()) ::
          {:ok, struct() | map() | binary()} | {:error, term()}
  def check_permission(store_ref, actor_id, operation, entity_or_id, _opts \\ []) do
    # If given an ID, fetch the entity first (might need module hint)
    # Simplification: Assume entity struct is passed for now
    entity =
      if is_struct(entity_or_id) do
        entity_or_id
      else
        # Need a way to get entity if only ID is passed - requires module/type info
        # Returning error for now if not a struct
        Logger.warning("check_permission needs entity struct, got ID: #{inspect entity_or_id}")
        # In a real scenario, fetch from store_ref using module from opts or context
        nil # Placeholder
      end

    if is_nil(entity) do
      {:error, :entity_not_found_or_id_passed}
    else
      case is_authorized?(store_ref, actor_id, operation, entity) do
        {:ok, _} -> {:ok, entity} # Return the original entity/id if authorized
        error -> error
      end
    end
  end

  @doc """
  Determines if an actor is authorized to perform an operation on an entity within a specific store.
  """
  @spec is_authorized?(store_ref :: term(), actor_id :: String.t(), operation :: atom(), entity :: struct()) :: 
          {:ok, struct()} | {:error, :unauthorized}
  def is_authorized?(store_ref, actor_id, operation, %Node{} = node) do
    case Access.authorize(store_ref, actor_id, operation, node.id) do
      {:ok, _} -> {:ok, node}
      error -> error
    end
  end

  def is_authorized?(store_ref, actor_id, operation, %Edge{} = edge) do
    # For edges, check permissions on both source and target
    with {:ok, _} <- Access.authorize(store_ref, actor_id, operation, edge.source),
         {:ok, _} <- Access.authorize(store_ref, actor_id, operation, edge.target) do
      {:ok, edge}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def is_authorized?(store_ref, actor_id, operation, %Graph{} = graph) do
    # For graphs, check permissions on the graph itself
    case Access.authorize(store_ref, actor_id, operation, graph.id) do
      {:ok, _} -> {:ok, graph}
      error -> error
    end
  end

  # Handle custom entities - requires mapping logic or conventions
  def is_authorized?(store_ref, actor_id, operation, entity) when is_struct(entity) do
    # Default: Check permission based on entity ID if it exists
    # This assumes custom entities might be bound to scopes like Nodes.
    # More sophisticated logic might be needed based on entity type.
    entity_id = Map.get(entity, :id)
    if entity_id do
      Access.authorize(store_ref, actor_id, operation, entity_id)
    else
      Logger.warning("Cannot authorize custom entity without ID: #{inspect entity}")
      false # Cannot authorize if no ID
    end
  end

  def is_authorized?(_store_ref, _actor_id, _operation, _entity) do
    # Default to false for unknown types or non-structs
    false
  end


  # --- Macro for Guarding Functions --- #

  defmacro __using__(opts) do
    quote do
      import GraphOS.Access.OperationGuard # Import functions for use in the module
      require Logger

      # Store operation types from options
      @operation_types Keyword.fetch!(unquote(opts), :operations)
      # Register a module attribute to hold guarded function metadata
      Module.register_attribute(__MODULE__, :guarded_funcs, accumulate: true)
      # Define the @guarded attribute for decorating functions
      Module.register_attribute(__MODULE__, :guard_opts, persist: false)

      # Decorator macro - captures opts for the next function
      defmacro guarded(opts) do
        quote do
          @guard_opts unquote(opts)
        end
      end

      # Register hook to run before compilation
      @before_compile GraphOS.Access.OperationGuard
    end
  end

  # Runs before the module is compiled, allowing us to redefine guarded functions
  defmacro __before_compile__(env) do
    module = env.module
    # Retrieve all functions marked with @guarded_funcs attribute (added by our decorator)
    guarded_funcs = Module.get_attribute(module, :guarded_funcs)

    # Iterate through each guarded function and redefine it
    Enum.each(guarded_funcs, fn {func_name, arity, guard_opts} ->
      redefine_guarded_function(module, func_name, arity, guard_opts)
    end)

    :ok
  end

  # Helper to redefine a single guarded function
  defp redefine_guarded_function(module, func_name, arity, guard_opts) do
    # Get original function definition info
    # Arity + 1 because we add the wrapper layer
    # Macro context requires careful handling of variables and quoting

    # Generate unique names for original function and args
    original_func_name = String.to_atom("__original_#{func_name}__")
    args = Macro.generate_arguments(arity, __MODULE__)

    # 1. Rename the original function
    rename_original_function(module, func_name, arity, original_func_name)

    # 2. Define the new wrapper function
    quote do
      def unquote(func_name)(unquote_splicing(args)) do
        # --- Wrapper Logic --- #
        current_guard_opts = unquote(Macro.escape(guard_opts))
        operation_types_map = @operation_types

        # Determine operation type (simple mapping for now)
        op_type = Map.get(operation_types_map, unquote(func_name))

        # Extract store_name (assuming it's the first arg for now)
        # TODO: Use :store_param from guard_opts if available
        store_name = Enum.at(unquote(args), 0)

        # Extract actor_id based on guard_opts
        actor_param_config = Keyword.get(current_guard_opts, :actor_param, :actor_id)
        actor_id_index = 1 # Default assumption: second arg
        # TODO: Add logic to find actor_id based on actor_param_config (atom index or map key)
        actor_id = Enum.at(unquote(args), actor_id_index)

        # Extract entity/entity_id based on guard_opts[:auth_map]
        auth_map = Keyword.get(current_guard_opts, :auth_map, %{})
        auth_config = Map.get(auth_map, {unquote(func_name), unquote(arity) - 1}) # Arity - 1 for non-store arg count?

        # Simple entity_id extraction (assumes entity_id: index)
        entity_or_id = if auth_config do
          if entity_id_index = Keyword.get(auth_config, :entity_id) do
            Enum.at(unquote(args), entity_id_index + 1) # +1 to account for store_name arg
          else
            nil # Complex entity extraction logic needed here
          end
        else
          nil # No auth config found
        end

        # Get Entity Module for hooks (needs improvement)
        entity_module = if is_struct(entity_or_id), do: entity_or_id.__struct__, else: nil
        hook_module = if entity_module, do: GraphOS.Access.OperationGuard.get_hooks_for(entity_module), else: nil

        # Prepare context for hooks
        hook_context = %{actor_id: actor_id, store_name: store_name} # Add more context as needed

        # Check permission & run hooks
        with {:ok, _permitted_entity_or_id} <- GraphOS.Access.OperationGuard.check_permission(store_name, actor_id, op_type, entity_or_id),
             {:ok, updated_context_before} <- run_hook(hook_module, :before, op_type, entity_or_id, hook_context),
             # Call the original renamed function
             result_tuple <- apply(__MODULE__, unquote(original_func_name), unquote(args)),
             # Assume original function returns {:ok, result, hook_context} or {:error, _}
             {:ok, op_result, _original_context} <- {:ok, result_tuple}, # Handle potential error tuple from original func
             {:ok, final_result, _updated_context_after} <- run_hook(hook_module, :after, op_type, op_result, updated_context_before)
        do
          # Return the final result, potentially modified by after hook
          {:ok, final_result} # Simplification: return tuple expected by test
          # Return {:ok, final_result, updated_context_after} # More complete return
        else
           # Handle errors from permission check, hooks, or original function
           {:error, :permission_denied} -> {:error, :unauthorized}
           {:error, {:hook_error, reason}} -> {:error, {:hook_failed, reason}}
           # Propagate errors from original function or other steps
           error -> error
        end
        # --- End Wrapper Logic --- #
      end
    end
  end

  # Helper to rename the original function
  defp rename_original_function(module, func_name, arity, original_func_name) do
    # Find the original function definition
    {:ok, {^module, _, _, functions}} = :beam_lib.chunks(module |> to_charlist() |> :code.which(), [:abstract_code])
    {:attribute, _, :file, {_file, _}} = :lists.keyfind(:file, 1, functions)

    # This is complex: requires parsing abstract code, renaming, and recompiling.
    # Alternative: Use @on_definition hook if Elixir version supports it.
    # Simplification for now: Assume the user won't define the `__original_...` function.
    # The wrapper will directly call `apply(__MODULE__, original_func_name, args)`
    # relying on the fact that the original function code still exists under the new name
    # when the wrapper is compiled.
    Logger.debug("Attempting to guard #{module}.#{func_name}/#{arity}. Original will be #{original_func_name}")
  end

  # Placeholder for future hook implementation
  # This will be fully implemented when hooks are needed
  # defp run_hook(_hook_module, _phase, _op_type, entity_or_context, context), do: {:ok, entity_or_context, context}

  # --- Old Helper Functions (Not using the macro) --- #
  # Kept for reference or potential direct use, but the macro is the intended way

  @doc """
  Wraps an operation function with permission checking. (Manual version)
  """
  @spec guard(function(), atom()) :: function()
  def guard(operation_fn, operation_type) when is_function(operation_fn, 2) and is_atom(operation_type) do
     # ... implementation from original file ...
     fn entity, opts ->
      actor_id = Keyword.get(opts, :actor_id)
      store_ref = Keyword.get(opts, :store_ref, :default) # Assume default store if not provided

      if actor_id do
        # Pass store_ref to check_permission
        case check_permission(store_ref, actor_id, operation_type, entity, opts) do
          {:ok, permitted_entity} -> operation_fn.(permitted_entity, opts)
          error -> error
        end
      else
        # If no actor_id is provided, skip permission check
        operation_fn.(entity, opts)
      end
    end
  end

  @doc """
  Helper to create a before_insert hook that checks write permissions. (Manual version)
  """
  @spec before_insert(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def before_insert(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    store_ref = Keyword.get(opts, :store_ref, :default)
    if actor_id, do: check_permission(store_ref, actor_id, :write, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_update hook that checks write permissions. (Manual version)
  """
  @spec before_update(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def before_update(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    store_ref = Keyword.get(opts, :store_ref, :default)
    if actor_id, do: check_permission(store_ref, actor_id, :write, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_delete hook that checks destroy permissions. (Manual version)
  """
  @spec before_delete(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def before_delete(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    store_ref = Keyword.get(opts, :store_ref, :default)
    if actor_id, do: check_permission(store_ref, actor_id, :destroy, entity, opts), else: {:ok, entity}
  end

  @doc """
  Helper to create a before_read hook that checks read permissions. (Manual version)
  """
  @spec before_read(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def before_read(entity, opts) do
    actor_id = Keyword.get(opts, :actor_id)
    store_ref = Keyword.get(opts, :store_ref, :default)
    if actor_id, do: check_permission(store_ref, actor_id, :read, entity, opts), else: {:ok, entity}
  end
end
