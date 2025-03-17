defprotocol GraphOS.Core.Executable do
  @moduledoc """
  Protocol for executable graph nodes.

  This protocol allows any graph node to be made executable, enabling
  operations to be performed when the node is executed. This is the core
  mechanism for binding functionality to nodes in the graph.

  ## Examples

      defimpl GraphOS.Core.Executable, for: MyCustomNode do
        def execute(node, context, access_context) do
          # Perform the operation
          {:ok, result}
        end
      end
  """

  @doc """
  Execute the node with the given context and access context.

  ## Parameters

  - `node` - The node to execute
  - `context` - Map of contextual information needed for execution
  - `access_context` - Optional access control context for permission checks

  ## Returns

  - `{:ok, result}` - Successful execution with result
  - `{:error, reason}` - Execution failed with reason

  ## Examples

      {:ok, result} = GraphOS.Core.Executable.execute(node, %{input: "value"})
  """
  @spec execute(t(), map(), term()) :: {:ok, any()} | {:error, term()}
  def execute(node, context \\ %{}, access_context \\ nil)
end

# Default implementation for any node
defimpl GraphOS.Core.Executable, for: Any do
  @moduledoc """
  Default implementation for the GraphOS.Core.Executable protocol.

  This provides a fallback implementation for any node type that doesn't
  explicitly implement the protocol. By default, nodes are not executable.
  """

  def execute(_node, _context, _access_context) do
    {:error, :not_executable}
  end
end

# Implementation for GraphOS.Graph.Node
defimpl GraphOS.Core.Executable, for: GraphOS.Graph.Node do
  @moduledoc """
  Implementation of the GraphOS.Core.Executable protocol for GraphOS.Graph.Node.

  This implementation provides execution behavior for standard graph nodes.
  It uses the following strategy:

  1. Check if the node has an "executable_type" property
  2. If present, delegate to the appropriate executor based on the type
  3. If not, check if the node has an "executable" property with code
  4. If neither is present, return :not_executable error
  """

  def execute(node, context, access_context) do
    # Try to execute based on node properties
    cond do
      # Check if the node has an executable_type property
      has_executable_type?(node) ->
        execute_by_type(node, context, access_context)

      # Check if the node has executable code directly
      has_executable_code?(node) ->
        execute_code(node, context, access_context)

      # Not executable
      true ->
        {:error, :not_executable}
    end
  end

  # Helper functions

  # Check if the node has an executable_type property
  defp has_executable_type?(node) do
    Map.has_key?(node.data, :executable_type) || Map.has_key?(node.data, "executable_type")
  end

  # Check if the node has executable code directly
  defp has_executable_code?(node) do
    Map.has_key?(node.data, :executable) || Map.has_key?(node.data, "executable")
  end

  # Get the executable type from the node
  defp get_executable_type(node) do
    Map.get(node.data, :executable_type) || Map.get(node.data, "executable_type")
  end

  # Get the executable code from the node
  defp get_executable_code(node) do
    Map.get(node.data, :executable) || Map.get(node.data, "executable")
  end

  # Execute the node based on its type
  defp execute_by_type(node, context, access_context) do
    executable_type = get_executable_type(node)

    # Dispatch to the appropriate executor based on type
    # This could be extended with a registry of executors
    case executable_type do
      "elixir_code" ->
        execute_code(node, context, access_context)

      "http_request" ->
        execute_http_request(node, context, access_context)

      "shell_command" ->
        execute_shell_command(node, context, access_context)

      _ ->
        {:error, {:unknown_executable_type, executable_type}}
    end
  end

  # Execute Elixir code
  defp execute_code(node, context, _access_context) do
    try do
      # Get the code from the node
      code = get_executable_code(node)

      if is_binary(code) do
        # Create a safe binding with the context
        bindings = [context: context, node: node]

        # Evaluate the code in a restricted environment
        # WARNING: This is extremely insecure and should be replaced with a proper sandbox
        # For a real implementation, consider using something like https://github.com/wojtekmach/mix_eval
        # or creating a proper sandbox with distributed Erlang nodes
        {result, _bindings} = Code.eval_string(code, bindings)

        {:ok, result}
      else
        {:error, :invalid_executable_code}
      end
    rescue
      e ->
        {:error, {:execution_error, e}}
    end
  end

  # Execute HTTP request
  defp execute_http_request(_node, _context, _access_context) do
    # This is a placeholder implementation
    # In a real system, you would use a proper HTTP client
    {:error, :not_implemented}
  end

  # Execute shell command
  defp execute_shell_command(_node, _context, _access_context) do
    # This is a placeholder implementation
    # In a real system, you would use a proper system command execution library
    # with appropriate security measures
    {:error, :not_implemented}
  end
end
