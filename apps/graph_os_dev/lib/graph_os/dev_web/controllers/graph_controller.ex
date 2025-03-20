defmodule GraphOS.DevWeb.CodeGraphController do
  @moduledoc """
  Controller for code graph data API endpoints.

  Provides JSON endpoints for code graph visualization data.
  Note: Currently disabled during refactoring.
  """
  use GraphOS.DevWeb, :controller
  require Logger

  @query_module Application.compile_env(:graph_os_dev, :query_module, GraphOS.Graph.Query)
  @code_graph_enabled Application.compile_env(:graph_os_dev, :enable_code_graph, false)

  # Message shown when CodeGraph is disabled
  @disabled_message "CodeGraph functionality is currently disabled during refactoring."

  @doc """
  Get graph data for a specific file
  """
  def file_data(conn, %{"path" => _file_path}) do
    if @code_graph_enabled do
      # Original implementation here (not called when disabled)
      conn
      |> put_status(503)
      |> json(%{error: %{message: @disabled_message}})
    else
      conn
      |> put_status(503)
      |> json(%{error: %{message: @disabled_message}})
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
  def module_data(conn, %{"name" => _module_name}) do
    if @code_graph_enabled do
      # Original implementation here (not called when disabled)
      conn
      |> put_status(503)
      |> json(%{error: %{message: @disabled_message}})
    else
      conn
      |> put_status(503)
      |> json(%{error: %{message: @disabled_message}})
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
    if @code_graph_enabled do
      # Original implementation here (not called when disabled)
      conn
      |> put_status(503)
      |> json(%{error: %{message: @disabled_message}})
    else
      # Return a placeholder response when disabled
      watch_dirs = Application.get_env(:graph_os_core, :watch_directories, ["lib"])
      file_pattern = Application.get_env(:graph_os_core, :file_pattern, "**/*.ex")
      
      # Just return empty data with a note that it's disabled
      json(conn, %{
        files: [],
        modules: [],
        stats: %{
          indexed_modules: 0,
          indexed_functions: 0,
          indexed_files: 0,
          disabled: true,
          watched_dirs: watch_dirs,
          file_pattern: file_pattern
        },
        notice: @disabled_message
      })
    end
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
