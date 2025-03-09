defmodule GraphOS.DevWeb.CodeGraphController do
  @moduledoc """
  Controller for code graph data API endpoints.

  Provides JSON endpoints for code graph visualization data.
  """
  use GraphOS.DevWeb, :controller
  require Logger

  @query_module Application.compile_env(:graph_os_mcp, :query_module, GraphOS.Graph.Query)

  @doc """
  Get graph data for a specific file
  """
  def file_data(conn, %{"path" => file_path}) do
    case get_graph_data_for_file(file_path) do
      {:ok, data} ->
        json(conn, data)
      {:error, error} ->
        conn
        |> put_status(400)
        |> json(%{error: format_error_message(error)})
    end
  end

  def file_data(conn, _) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing file path parameter"})
  end

  @doc """
  Get graph data for a specific module
  """
  def module_data(conn, %{"name" => module_name}) do
    case get_graph_data_for_module(module_name) do
      {:ok, data} ->
        json(conn, data)
      {:error, error} ->
        conn
        |> put_status(400)
        |> json(%{error: format_error_message(error)})
    end
  end

  def module_data(conn, _) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing module name parameter"})
  end

  @doc """
  Get lists of files and modules
  """
  def list_data(conn, _params) do
    case get_files_and_modules() do
      {:ok, data} ->
        json(conn, data)
      {:error, error} ->
        conn
        |> put_status(500)
        |> json(%{error: format_error_message(error)})
    end
  end

  # Private helper functions

  defp get_files_and_modules do
    try do
      # Check if the CodeGraph service is running
      case Process.whereis(GraphOS.Core.CodeGraph.Service) do
        nil ->
          # Service is not running, return error
          Logger.warning("CodeGraph.Service is not running. Unable to fetch files and modules list.")
          {:error, "CodeGraph service not available. Please ensure it's enabled in your configuration."}

        _pid ->
          # Get status from CodeGraph service to get indexed modules info
          case GraphOS.Core.CodeGraph.Service.status() do
            {:ok, status} ->
              # Get files using FileWatcher functionality
              # We'll use the same directories configured for CodeGraph
              watch_dirs = Application.get_env(:graph_os_core, :watch_directories, ["lib"])
              file_pattern = Application.get_env(:graph_os_core, :file_pattern, "**/*.ex")
              exclude_pattern = Application.get_env(:graph_os_core, :exclude_pattern)

              # Get all files matching the pattern in all directories
              files = get_files_from_directories(watch_dirs, file_pattern, exclude_pattern)

              # Get modules from the code graph
              case GraphOS.Graph.Query.find_nodes_by_properties(%{}) do
                {:ok, nodes} ->
                  # Extract modules from nodes
                  modules = Enum.reduce(nodes, [], fn node, modules_acc ->
                    if node.id =~ ~r/^[A-Z].*\..*/ do
                      [node.id | modules_acc]
                    else
                      modules_acc
                    end
                  end)

                  # Return unique sorted lists
                  {:ok, %{
                    files: Enum.uniq(files) |> Enum.sort(),
                    modules: Enum.uniq(modules) |> Enum.sort(),
                    stats: %{
                      indexed_modules: status[:modules] || 0,
                      indexed_functions: status[:functions] || 0,
                      indexed_files: status[:files] || 0
                    }
                  }}

                {:error, reason} ->
                  Logger.error("Failed to query graph nodes: #{inspect(reason)}")
                  {:error, "Failed to retrieve modules from graph"}
              end

            {:error, reason} ->
              Logger.error("Failed to get CodeGraph service status: #{inspect(reason)}")
              {:error, "Failed to communicate with CodeGraph service"}
          end
      end
    rescue
      e ->
        Logger.error("Error in get_files_and_modules: #{inspect(e)}")
        {:error, Exception.message(e)}
    end
  end

  # Helper function to get files from directories respecting .gitignore
  defp get_files_from_directories(directories, file_pattern, exclude_pattern) do
    # Get all files matching the pattern in all directories
    all_files =
      Enum.flat_map(directories, fn dir ->
        pattern = Path.join(dir, file_pattern)
        Path.wildcard(pattern)
      end)
      |> Enum.map(&normalize_path/1) # Normalize paths for consistency

    # Filter out excluded files and respect .gitignore
    filtered_files =
      if exclude_pattern do
        exclude_paths = Path.wildcard(exclude_pattern) |> Enum.map(&normalize_path/1)
        Enum.reject(all_files, & &1 in exclude_paths)
      else
        all_files
      end

    # Further filter to respect .gitignore patterns
    # First find all .gitignore files in project
    gitignore_files = find_gitignore_files(directories)

    # Parse gitignore patterns
    gitignore_patterns = parse_gitignore_files(gitignore_files)

    # Filter out files matching gitignore patterns
    Enum.reject(filtered_files, fn file ->
      matches_gitignore?(file, gitignore_patterns)
    end)
  end

  # Normalize file paths to ensure consistency
  defp normalize_path(path) do
    # Convert absolute paths to relative from project root
    case Path.type(path) do
      :absolute ->
        # Try to make it relative to the application root
        project_root = Application.app_dir(:graph_os_dev) |> Path.dirname() |> Path.dirname()
        case Path.relative_to(path, project_root) do
          ^path -> path # If unchanged, it wasn't under project_root
          relative_path -> relative_path
        end
      _ -> path # Already relative, return as is
    end
    |> String.replace("\\", "/") # Normalize separators for cross-platform consistency
  end

  # Find all .gitignore files in the project
  defp find_gitignore_files(directories) do
    Enum.flat_map(directories, fn dir ->
      base_dir = Path.join([dir, ".."])
      Path.wildcard(Path.join([base_dir, "**/.gitignore"]))
    end)
  end

  # Parse gitignore files into a list of patterns
  defp parse_gitignore_files(gitignore_files) do
    Enum.flat_map(gitignore_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          base_dir = Path.dirname(file)

          content
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(fn line -> line == "" or String.starts_with?(line, "#") end)
          |> Enum.map(fn pattern -> {Path.join(base_dir, pattern), pattern} end)

        {:error, _} -> []
      end
    end)
  end

  # Check if a file matches any gitignore pattern
  defp matches_gitignore?(file, gitignore_patterns) do
    Enum.any?(gitignore_patterns, fn {full_pattern, pattern} ->
      # Handle different pattern types (exact, directory, wildcard)
      cond do
        # Exact file match
        Path.wildcard(full_pattern) |> Enum.member?(file) -> true

        # Directory match (pattern ends with /)
        String.ends_with?(pattern, "/") and String.starts_with?(file, String.trim_trailing(full_pattern, "/")) -> true

        # Wildcard pattern
        String.contains?(pattern, "*") and Path.wildcard(full_pattern) |> Enum.member?(file) -> true

        # No match
        true -> false
      end
    end)
  end

  defp get_graph_data_for_file(file_path) do
    try do
      # Fetch nodes and edges associated with this file
      case @query_module.execute(start_node_id: file_path, depth: 2) do
        {:ok, results} ->
          {:ok, %{nodes: results}}
        {:error, reason} ->
          # Format the error message for JSON encoding
          error_message = format_error_message(reason)
          {:error, error_message}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp get_graph_data_for_module(module_name) do
    try do
      # Check if the CodeGraph service is running
      case Process.whereis(GraphOS.Core.CodeGraph.Service) do
        nil ->
          # Service is not running
          Logger.warning("CodeGraph.Service is not running. Unable to fetch module data.")
          {:error, "CodeGraph service not available. Please ensure it's enabled in your configuration."}

        _pid ->
          # Service is running, try to query it
          case GraphOS.Core.CodeGraph.Service.query_module(module_name) do
            {:ok, module_info} ->
              # Transform the module info into a format suitable for visualization
              {:ok, transform_module_info_for_visualization(module_info)}
            {:error, reason} ->
              # Format the error message for JSON encoding
              error_message = format_error_message(reason)
              {:error, error_message}
          end
      end
    rescue
      e ->
        Logger.error("Error getting graph data for module #{module_name}: #{inspect(e)}")
        {:error, "Failed to get graph data for module: #{Exception.message(e)}"}
    end
  end

  # Transform module info from CodeGraph.Service into visualization format
  defp transform_module_info_for_visualization(module_info) do
    # Extract nodes and edges from the module info
    # This is a simplified implementation - you may need to adjust based on your actual data structure
    module_node = module_info[:module]
    function_nodes = module_info[:functions] || []
    dependency_nodes = module_info[:dependencies] || []

    # Combine all nodes
    nodes = [module_node] ++ function_nodes ++ dependency_nodes

    # Return in format expected by the visualization
    %{
      nodes: nodes,
      module: module_node
    }
  end

  # Format error messages for JSON encoding
  defp format_error_message(reason) do
    case reason do
      # Handle ETS error tuples
      {kind, error, stacktrace} when is_atom(kind) and is_list(stacktrace) ->
        message = "#{kind}: #{inspect(error)}"
        %{message: message, details: "Error processing graph data"}

      # Handle atom errors
      error when is_atom(error) ->
        %{message: "#{error}", details: "Error processing graph data"}

      # Handle string errors
      error when is_binary(error) ->
        %{message: error, details: "Error processing graph data"}

      # Handle any other error format
      _ ->
        %{message: "Unknown error", details: "Error processing graph data"}
    end
  end
end
