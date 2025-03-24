defmodule GraphOS.Dev.CodeParser do
  @moduledoc """
  Parser for Elixir source files.

  This module extracts structural information from Elixir source files, including:
  - Modules and their attributes
  - Functions and their signatures
  - Dependencies between modules
  - Documentation and metadata

  The parser uses Elixir's AST for accurate code analysis without relying on regex or text parsing.
  """

  @doc """
  Parse an Elixir source file and extract its structure.

  ## Parameters

  - `file_path` - Path to the Elixir source file

  ## Returns

  A map containing:
  - `:modules` - List of module definitions found
  - `:functions` - List of function definitions found
  - `:dependencies` - List of module dependencies found
  - `:errors` - List of parsing errors (if any)

  ## Examples

      iex> GraphOS.Dev.CodeParser.parse_file("lib/my_module.ex")
      {:ok, %{modules: [...], functions: [...], dependencies: [...]}}

  """
  @spec parse_file(Path.t()) :: {:ok, map()} | {:error, term()}
  def parse_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, ast} <- parse_string(content) do
      # Process the AST to extract information
      result = process_ast(ast, file_path)
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse an Elixir source string and extract its structure.

  Similar to `parse_file/1` but works with a string instead of a file.

  ## Parameters

  - `source` - Elixir source code as a string
  - `file_path` - Optional file path for context (default: "nofile")

  ## Examples

      iex> source = "defmodule MyModule do\\n  def hello, do: :world\\nend"
      iex> GraphOS.Dev.CodeParser.parse_string(source)
      {:ok, ast}

  """
  @spec parse_string(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def parse_string(source, file_path \\ "nofile") do
    try do
      {:ok, Code.string_to_quoted!(source, file: file_path, columns: true)}
    rescue
      e ->
        {:error, "Failed to parse: #{Exception.message(e)}"}
    end
  end

  @doc """
  Process an Elixir AST and extract structural information.

  ## Parameters

  - `ast` - Elixir AST (usually from Code.string_to_quoted!/2)
  - `file_path` - Path to the source file (for tracking)

  ## Examples

      iex> ast = quote do
      ...>   defmodule MyModule do
      ...>     def hello, do: :world
      ...>   end
      ...> end
      iex> GraphOS.Dev.CodeParser.process_ast(ast, "my_module.ex")
      %{modules: [...], functions: [...], dependencies: [...]}

  """
  @spec process_ast(term(), String.t()) :: map()
  def process_ast(ast, _file_path) do
    # Initialize empty result
    result = %{
      modules: [],
      functions: [],
      dependencies: [],
      errors: []
    }

    # Process the AST
    {_, result} = Macro.traverse(ast, result, &pre_traverse/2, &post_traverse/2)

    # Return the result
    result
  end

  # Private functions

  # Pre-traversal processing of AST nodes
  defp pre_traverse({:defmodule, meta, [module_name | _rest]} = node, acc) do
    # Extract module name
    module = extract_module_name(module_name)

    # Add to modules list
    line = meta[:line] || 0

    # Extract documentation from the AST
    # This is simplistic; a real implementation would look for @moduledoc attributes
    doc = ""

    module_data = %{
      name: module,
      line: line,
      documentation: doc
    }

    acc = update_in(acc[:modules], &[module_data | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle function definitions
  defp pre_traverse({:def, meta, [{function_name, _func_meta, args} | _rest]} = node, acc) do
    # Get the current module context (should be set during module traversal)
    module = Map.get(acc, :current_module, "Unknown")

    # Extract function info
    line = meta[:line] || 0
    name = to_string(function_name)
    arity = if is_list(args), do: length(args), else: 0

    # Extract documentation (simplified)
    doc = ""

    function_data = %{
      module: module,
      name: name,
      arity: arity,
      line: line,
      documentation: doc,
      visibility: :public
    }

    acc = update_in(acc[:functions], &[function_data | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle private function definitions
  defp pre_traverse({:defp, meta, [{function_name, _func_meta, args} | _rest]} = node, acc) do
    # Get the current module context (should be set during module traversal)
    module = Map.get(acc, :current_module, "Unknown")

    # Extract function info
    line = meta[:line] || 0
    name = to_string(function_name)
    arity = if is_list(args), do: length(args), else: 0

    # Extract documentation (simplified)
    doc = ""

    function_data = %{
      module: module,
      name: name,
      arity: arity,
      line: line,
      documentation: doc,
      visibility: :private
    }

    acc = update_in(acc[:functions], &[function_data | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle module attributes like @moduledoc, @behaviour, etc.
  defp pre_traverse({:@, _, [{attr_name, _, [value]}]} = node, acc)
       when attr_name in [:moduledoc, :doc, :behaviour, :protocol_impl] do
    # Process module attributes to extract docs and dependencies
    case attr_name do
      :moduledoc ->
        # Store documentation for the current module
        # (This would be more complex in a real implementation)
        {node, acc}

      :behaviour ->
        # Record behavior dependency
        module = Map.get(acc, :current_module, "Unknown")
        behaviour = extract_module_name(value)

        dependency = %{
          source: module,
          target: behaviour,
          type: "implements"
        }

        acc = update_in(acc[:dependencies], &[dependency | &1])
        {node, acc}

      _ ->
        {node, acc}
    end
  end

  # Handle import statements
  defp pre_traverse({:import, _, [module_name | _rest]} = node, acc) do
    # Get the current module context
    current_module = Map.get(acc, :current_module, "Unknown")

    # Extract the imported module name
    imported_module = extract_module_name(module_name)

    # Add to dependencies
    dependency = %{
      source: current_module,
      target: imported_module,
      type: "imports"
    }

    acc = update_in(acc[:dependencies], &[dependency | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle alias statements
  defp pre_traverse({:alias, _, [module_name | _rest]} = node, acc) do
    # Get the current module context
    current_module = Map.get(acc, :current_module, "Unknown")

    # Extract the aliased module name
    aliased_module = extract_module_name(module_name)

    # Add to dependencies
    dependency = %{
      source: current_module,
      target: aliased_module,
      type: "references"
    }

    acc = update_in(acc[:dependencies], &[dependency | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle use statements
  defp pre_traverse({:use, _, [module_name | _rest]} = node, acc) do
    # Get the current module context
    current_module = Map.get(acc, :current_module, "Unknown")

    # Extract the used module name
    used_module = extract_module_name(module_name)

    # Add to dependencies
    dependency = %{
      source: current_module,
      target: used_module,
      type: "uses"
    }

    acc = update_in(acc[:dependencies], &[dependency | &1])

    # Continue traversal
    {node, acc}
  end

  # Handle function calls to other modules
  defp pre_traverse({{:., _, [module_name, function_name]}, _, args} = node, acc)
       when is_atom(function_name) and is_list(args) do
    # Get the current module context
    current_module = Map.get(acc, :current_module, "Unknown")

    # Extract the called module name
    called_module = extract_module_name(module_name)

    # Skip Elixir built-ins and same-module calls
    if called_module != current_module and not elixir_builtin?(called_module) do
      # Add to dependencies
      dependency = %{
        source: current_module,
        target: called_module,
        type: "calls"
      }

      updated_acc = update_in(acc[:dependencies], &[dependency | &1])
      updated_acc
    else
      acc
    end

    # Continue traversal
    {node, acc}
  end

  # Default handler for other AST nodes
  defp pre_traverse(node, acc) do
    {node, acc}
  end

  # Post-traversal processing (to handle scope exit)
  defp post_traverse({:defmodule, _, [_module_name | _rest]} = node, acc) do
    # When we exit a module scope, clear the current_module tracking
    {node, Map.delete(acc, :current_module)}
  end

  # Default post handler
  defp post_traverse(node, acc) do
    {node, acc}
  end

  # Extract a module name from its AST representation
  defp extract_module_name({:__aliases__, _, parts}) when is_list(parts) do
    Enum.map_join(parts, ".", &to_string/1)
  end

  defp extract_module_name(module) when is_atom(module) do
    to_string(module)
  end

  defp extract_module_name(_), do: "Unknown"

  # Check if a module is an Elixir built-in
  defp elixir_builtin?(module_name) do
    String.starts_with?(module_name, "Elixir.") or
      module_name in ~w(Kernel Enum Map String List Process Application)
  end
end
