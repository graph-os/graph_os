defmodule GraphOS.Core.CodeGraph do
  @moduledoc """
  Core module for building and analyzing the code structure graph.

  This module provides functionality to:
  - Build a graph representation of Elixir code
  - Store and query relationships between modules, functions, and files
  - Monitor changes to the codebase and update the graph in real-time
  - Provide insights about code structure and dependencies

  The graph structure follows these conventions:
  - Nodes: Modules, functions, files
  - Edges: Function calls, imports, uses, behaviours, implementations
  - Properties: Documentation, line numbers, metadata
  """

  alias GraphOS.Graph
  alias GraphOS.Graph.{Node, Transaction, Query}
  alias GraphOS.Core.CodeParser

  @doc """
  Initialize a new code graph.

  This initializes the graph store and creates the necessary graph schema.

  ## Examples

      iex> GraphOS.Core.CodeGraph.init()
      :ok

  """
  @spec init() :: :ok | {:error, term()}
  def init do
    # Graph.init now returns :ok directly
    case Graph.init() do
      :ok -> :ok
      error -> error
    end
  end

  @doc """
  Build the code graph for a specific directory.

  ## Parameters

  - `directory` - The directory to scan
  - `opts` - Options for building the graph

  ## Options

  - `:recursive` - Whether to recursively scan subdirectories (default: true)
  - `:file_pattern` - Pattern for matching files (default: "**/*.ex")
  - `:exclude_pattern` - Pattern for excluding files (optional)

  ## Examples

      iex> GraphOS.Core.CodeGraph.build_graph("lib")
      {:ok, stats}

      iex> GraphOS.Core.CodeGraph.build_graph("lib", recursive: false)
      {:ok, stats}

  """
  @spec build_graph(Path.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def build_graph(directory, opts \\ []) do
    # Default options
    recursive = Keyword.get(opts, :recursive, true)
    file_pattern = Keyword.get(opts, :file_pattern, "**/*.ex")
    exclude_pattern = Keyword.get(opts, :exclude_pattern, nil)

    # Path to scan
    path_pattern = Path.join(directory, file_pattern)

    # Statistics to return
    stats = %{
      processed_files: 0,
      modules: 0,
      functions: 0,
      relationships: 0
    }

    # Find all matching files
    files =
      if recursive do
        Path.wildcard(path_pattern)
      else
        # Non-recursive path matching
        path_pattern
        |> Path.wildcard()
        |> Enum.filter(fn path ->
          Path.dirname(path) == directory
        end)
      end

    # Filter out excluded files if an exclude pattern is provided
    files =
      if exclude_pattern do
        exclude_paths = Path.wildcard(exclude_pattern)
        Enum.reject(files, &(&1 in exclude_paths))
      else
        files
      end

    # Process each file with error handling
    result =
      files
      |> Enum.reduce({:ok, stats}, fn file, {:ok, current_stats} ->
        case process_file(file, current_stats) do
          {:ok, updated_stats} ->
            {:ok, updated_stats}
          {:error, reason} ->
            # Log the error but continue processing
            require Logger
            Logger.error("Failed to process file #{file}: #{inspect(reason)}")
            # Return unchanged stats to continue processing
            {:ok, current_stats}
        end
      end)

    # Return statistics about the build
    result
  end

  @doc """
  Get information about a module.

  ## Parameters

  - `module_name` - The name of the module

  ## Examples

      iex> GraphOS.Core.CodeGraph.get_module_info("GraphOS.Core.CodeGraph")
      {:ok, module_data}

  """
  @spec get_module_info(String.t()) :: {:ok, map()} | {:error, term()}
  def get_module_info(module_name) do
    case Query.get_node(module_name) do
      {:ok, node} ->
        # Fetch related information
        {:ok, related_functions} =
          Query.execute(start_node_id: module_name, edge_type: "defines")

        # Fetch dependencies
        {:ok, dependencies} =
          Query.execute(start_node_id: module_name, edge_type: "depends_on")

        # Combine all data
        {:ok, %{
          module: node,
          functions: related_functions,
          dependencies: dependencies
        }}
      {:error, _reason} ->
        # Try looking up with a case-insensitive approach (module name might have different casing)
        case find_module_by_name(module_name) do
          {:ok, actual_module_name} ->
            get_module_info(actual_module_name)
          _ ->
            {:error, :not_found}
        end
    end
  end

  # Helper to find a module by its name regardless of case
  defp find_module_by_name(module_name) do
    # Look for nodes that might be modules with similar names
    with {:ok, nodes} <- Query.find_nodes_by_properties(%{}) do
      # Filter nodes that might be modules matching the name (case insensitive)
      module_node = Enum.find(nodes, fn node ->
        String.downcase(node.id) == String.downcase(module_name)
      end)

      case module_node do
        nil -> {:error, :not_found}
        node -> {:ok, node.id}
      end
    end
  end

  @doc """
  Find modules that implement a specific protocol or behaviour.

  ## Parameters

  - `protocol_or_behaviour` - The name of the protocol or behaviour

  ## Examples

      iex> GraphOS.Core.CodeGraph.find_implementations("GraphOS.Graph.Protocol")
      {:ok, [module_names]}

  """
  @spec find_implementations(String.t()) :: {:ok, list(String.t())} | {:error, term()}
  def find_implementations(protocol_or_behaviour) do
    # Query for nodes that have an "implements" edge to the protocol
    case Query.execute(
      start_node_id: protocol_or_behaviour,
      edge_type: "implemented_by",
      direction: :incoming
    ) do
      {:ok, nodes} ->
        {:ok, Enum.map(nodes, & &1.id)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find modules dependent on a specific module.

  ## Parameters

  - `module_name` - The name of the module

  ## Examples

      iex> GraphOS.Core.CodeGraph.find_dependents("GraphOS.Graph")
      {:ok, [module_names]}

  """
  @spec find_dependents(String.t()) :: {:ok, list(String.t())} | {:error, term()}
  def find_dependents(module_name) do
    # Query for nodes that have a "depends_on" edge to the module
    case Query.execute(
      start_node_id: module_name,
      edge_type: "depends_on",
      direction: :incoming
    ) do
      {:ok, nodes} ->
        {:ok, Enum.map(nodes, & &1.id)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update the graph with a file that has changed.

  ## Parameters

  - `file_path` - Path to the changed file
  - `opts` - Options for updating

  ## Examples

      iex> GraphOS.Core.CodeGraph.update_file("lib/my_module.ex")
      {:ok, changes}

  """
  @spec update_file(Path.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_file(file_path, _opts \\ []) do
    # First clear existing nodes and edges for this file
    with :ok <- remove_file_from_graph(file_path) do
      # Then process the file as new
      stats = %{
        processed_files: 0,
        modules: 0,
        functions: 0,
        relationships: 0
      }

      process_file(file_path, stats)
    end
  end

  # Private functions

  # Process a single source file and add its contents to the graph
  defp process_file(file_path, stats) do
    # Parse the file
    case CodeParser.parse_file(file_path) do
      {:ok, parsed_data} ->
        # Add nodes and edges for the parsed content
        add_to_graph(parsed_data, file_path, stats)

      {:error, reason} ->
        {:error, "Failed to parse #{file_path}: #{inspect(reason)}"}
    end
  end

  # Add parsed content to the graph
  defp add_to_graph(parsed_data, file_path, stats) do
    # Initialize a transaction
    transaction = Transaction.new(GraphOS.Graph.Store.ETS)

    # Extract data
    modules = parsed_data.modules
    functions = parsed_data.functions
    dependencies = parsed_data.dependencies

    # Add modules as nodes
    transaction =
      Enum.reduce(modules, transaction, fn module, tx ->
        module_node = Node.new(
          %{
            name: module.name,
            file: file_path,
            line: module.line,
            documentation: module.documentation
          },
          [id: module.name]
        )

        # Add operation to transaction
        Transaction.add(tx, GraphOS.Graph.Operation.new(:create, :node, module_node, [id: module.name]))
      end)

    # Add functions as nodes
    transaction =
      Enum.reduce(functions, transaction, fn function, tx ->
        function_id = "#{function.module}##{function.name}/#{function.arity}"
        function_node = Node.new(
          %{
            name: function.name,
            arity: function.arity,
            module: function.module,
            file: file_path,
            line: function.line,
            documentation: function.documentation,
            visibility: function.visibility
          },
          [id: function_id]
        )

        # Add function node
        tx = Transaction.add(tx, GraphOS.Graph.Operation.new(:create, :node, function_node, [id: function_id]))

        # Add edge from module to function (defines relationship)
        Transaction.add(tx, GraphOS.Graph.Operation.new(:create, :edge, %{}, [
          id: "#{function.module}->#{function_id}",
          key: "defines",
          weight: 1,
          source: function.module,
          target: function_id
        ]))
      end)

    # Add dependencies as edges
    transaction =
      Enum.reduce(dependencies, transaction, fn dependency, tx ->
        source = dependency.source
        target = dependency.target

        # Add operation to transaction
        Transaction.add(tx, GraphOS.Graph.Operation.new(:create, :edge, %{}, [
          id: "#{source}->#{target}",
          key: dependency.type,
          weight: 1,
          source: source,
          target: target
        ]))
      end)

    # Execute the transaction
    case Graph.execute(transaction) do
      {:ok, _result} ->
        # Update statistics
        updated_stats = %{
          processed_files: stats.processed_files + 1,
          modules: stats.modules + length(modules),
          functions: stats.functions + length(functions),
          relationships: stats.relationships + length(dependencies)
        }

        {:ok, updated_stats}

      {:error, reason} ->
        {:error, "Failed to add to graph: #{inspect(reason)}"}
    end
  end

  # Remove a file's nodes and edges from the graph
  defp remove_file_from_graph(file_path) do
    # Find all nodes associated with this file
    case Query.find_nodes_by_properties(%{file: file_path}) do
      {:ok, nodes} ->
        # Create a transaction to remove all these nodes
        transaction = Transaction.new(GraphOS.Graph.Store.ETS)

        # Add delete operations for each node
        transaction =
          Enum.reduce(nodes, transaction, fn node, tx ->
            Transaction.add(tx, GraphOS.Graph.Operation.new(:delete, :node, %{}, [id: node.id]))
          end)

        # Execute the transaction
        case Graph.execute(transaction) do
          {:ok, _result} -> :ok
          error -> error
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
