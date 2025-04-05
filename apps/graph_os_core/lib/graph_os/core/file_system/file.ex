defmodule GraphOS.Core.FileSystem.File do
  @moduledoc """
  Represents a File node within the FileSystem graph.
  Implements `GraphOS.Entity.Node` and handles file-specific actions.
  """
  use GraphOS.Entity.Node # Assuming this exists and sets up entity behaviour (including defstruct)

  require Logger # Added require for Logger macros
  alias GraphOS.Conn
  alias GraphOS.Core.FileSystem # Alias real implementation

  # Allow injecting the graph module dependency for testing
  @file_system_graph_module Application.compile_env(:graph_os_core, __MODULE__, file_system_graph_module: FileSystem)

  # Define the @action_meta attribute
  require GraphOS.Action.Behaviour
  Module.register_attribute(__MODULE__, :action_meta, accumulate: true, persist: true)

  # --- Action Metadata (Example - Association needs refinement) ---
  @read_meta %{
    description: "Reads the content of this file.",
    input_schema: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path to the file"}
      },
      "required" => ["path"] # Path is needed to identify the file if not passed as struct
    }
  }
  @write_meta %{
    description: "Writes content to this file.",
    input_schema: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path to the file"},
        "content" => %{"type" => "string", "description" => "Content to write"}
      },
      "required" => ["path", "content"]
    }
  }

  # --- Execution Entry Point ---

  @doc """
  Executes an operation on a File node.

  Handles resolving the target node based on the payload (using the provided store_ref)
  and delegates execution orchestration to GraphOS.Action.
  """
  def execute(store_ref, conn, payload, opts \\ []) do
    # 1. Resolve Node, Scope ID and Extract Operation Details (pass store_ref)
    case resolve_node_and_operation(store_ref, conn, payload) do
      {:ok, _node, scope_id, operation_atom, operation_args, meta} ->
        # 2. Delegate to Action Service
        # Pass the explicitly resolved/provided scope_id for authorization check
        GraphOS.Action.request_execution(store_ref, conn, scope_id, __MODULE__, operation_atom, operation_args, meta, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Node Resolution & Operation Extraction ---

  # Handles different payload types to find the node, scope_id, and operation details
  # Now includes store_ref positionally
  # Case 1: Payload includes node struct and scope_id explicitly
  defp resolve_node_and_operation(_store_ref, _conn, {%__MODULE__{} = node, scope_id, operation_atom, operation_args})
       when is_binary(scope_id) and is_atom(operation_atom) do
     meta = get_operation_meta(operation_atom)
     {:ok, node, scope_id, operation_atom, operation_args, meta}
  end
  # Case 2: Payload includes node ID and action string (derive scope_id from node_id for now)
  # TODO: Refine how scope_id is determined when only node_id is given. Might need find_scopes_for_node.
  defp resolve_node_and_operation(store_ref, conn, %{"id" => node_id, "action" => op_string, "args" => operation_args}) do
    with {:ok, node} <- apply(@file_system_graph_module, :get, [store_ref, conn, node_id]),
         {:ok, operation_atom} <- parse_operation_atom(op_string) do
       meta = get_operation_meta(operation_atom)
       operation_args_with_id = Map.put(operation_args || %{}, "id", node_id)
       # For now, assume node_id IS the scope_id if not otherwise specified
       scope_id = node.id
       {:ok, node, scope_id, operation_atom, operation_args_with_id, meta}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_operation_atom}
    end
  end
  # Case 3: Payload includes path and action string (derive scope_id from path)
   defp resolve_node_and_operation(store_ref, conn, %{"path" => path, "action" => op_string, "args" => operation_args}) do
    with {:ok, node} <- apply(@file_system_graph_module, :get_by_path, [store_ref, conn, path]),
         {:ok, operation_atom} <- parse_operation_atom(op_string) do
       meta = get_operation_meta(operation_atom)
       # Derive scope_id from path (consistent with test setup)
       scope_id = "file-scope-#{path |> Path.basename() |> String.replace(~r/[^a-zA-Z0-9]/, "-")}"
       # Add node identifier back into args if needed by do_operation
       # Corrected: use path variable here, not node_id which might not exist in this clause's scope
       operation_args_with_path = Map.put(operation_args || %{}, "path", path)
       {:ok, node, scope_id, operation_atom, operation_args_with_path, meta}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_operation_atom}
    end
  end
  defp resolve_node_and_operation(_store_ref, _conn, _payload) do
    {:error, :invalid_payload_format}
  end

  # Helper to get metadata (replace with actual lookup if stored differently)
  defp get_operation_meta(:read), do: @read_meta
  defp get_operation_meta(:write), do: @write_meta
  defp get_operation_meta(_), do: %{} # Default empty meta

  # Helper to safely convert string to atom
  defp parse_operation_atom(op_string) when is_binary(op_string) do
    try do
      {:ok, String.to_existing_atom(op_string)}
    rescue
      ArgumentError -> :error
    end
  end
  defp parse_operation_atom(_), do: :error


  # --- Internal Implementation Functions (called by Runner) ---
  # These are called by the GraphOS.Action.Runner via apply/3

  @doc false
  def do_read(args) do # Ensure this is public
    path = Map.fetch!(args, "path")
    Logger.debug("Executing do_read for path: #{path}")
    # Actual file reading logic with basic error handling
    File.read(path)
  end

  @doc false
  def do_write(args) do # Ensure this is public
    path = Map.fetch!(args, "path")
    content = Map.fetch!(args, "content")
    Logger.debug("Executing do_write for path: #{path}")
    # Actual file writing logic with basic error handling
    File.write(path, content)
  end
end
