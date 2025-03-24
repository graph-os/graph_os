defmodule GraphOS.DevWeb.CodeGraphLive.File do
  @moduledoc """
  LiveView for file-based code graph visualization.

  This view allows visualizing the graph structure of a specific file.
  """
  use GraphOS.DevWeb, :live_view
  require Logger

  alias GraphOS.Dev.CodeGraph.Service, as: CodeGraphService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "File Graph Visualization",
       file_path: "",
       graph_data: nil,
       loading: false,
       error: nil
     )}
  end

  @impl true
  def handle_params(%{"path" => path}, _url, socket) when is_binary(path) and path != "" do
    # Fetch graph data for this path
    send(self(), {:fetch_graph_data, path})

    {:noreply, assign(socket, file_path: path, loading: true)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"file" => %{"path" => path}}, socket) do
    # Redirect to the same page with the path as a query parameter
    # This allows bookmarking and sharing specific file views
    {:noreply, push_patch(socket, to: ~p"/code-graph/file?path=#{path}")}
  end

  @impl true
  def handle_info({:fetch_graph_data, path}, socket) do
    case fetch_graph_data(path) do
      {:ok, data} ->
        {:noreply, assign(socket, graph_data: data, loading: false, error: nil)}

      {:error, error} ->
        {:noreply, assign(socket, loading: false, error: error, graph_data: nil)}
    end
  end

  defp fetch_graph_data(path) do
    # Directly use the CodeGraphController's helper function to get file data
    # This avoids an unnecessary HTTP request
    try do
      # Normalize path for consistency with how paths are stored
      normalized_path = normalize_path(path)

      # Check if the CodeGraph service is running
      case Process.whereis(CodeGraphService) do
        nil ->
          # Service is not running
          Logger.warning("CodeGraph.Service is not running. Unable to fetch file data.")

          {:error,
           "CodeGraph service not available. Please ensure it's enabled in your configuration."}

        _pid ->
          # Use the Graph.Query module to get file data
          query_module = Application.get_env(:graph_os_dev, :query_module, GraphOS.Store.Query)

          # First, try to find nodes with this file path
          query = GraphOS.Store.Query.find_nodes_by_properties(%{file: normalized_path})

          case GraphOS.Store.execute(query) do
            {:ok, nodes} when length(nodes) > 0 ->
              # If we found a node, use its ID for the query
              [node | _] = nodes

              case query_module.execute(start_node_id: node.id, depth: 2) do
                {:ok, results} -> {:ok, %{nodes: results}}
                {:error, reason} -> {:error, format_error(reason)}
              end

            {:ok, []} ->
              # Try a direct path query as a fallback
              case query_module.execute(start_node_id: normalized_path, depth: 2) do
                {:ok, results} ->
                  if Enum.empty?(results) do
                    # Try with the original path as a last resort
                    case query_module.execute(start_node_id: path, depth: 2) do
                      {:ok, results} when results != [] ->
                        {:ok, %{nodes: results}}

                      _ ->
                        {:error,
                         "No graph data found for this file. The file may not be indexed yet."}
                    end
                  else
                    {:ok, %{nodes: results}}
                  end

                {:error, reason} ->
                  {:error, format_error(reason)}
              end

            {:error, reason} ->
              # Error in the find_nodes query
              {:error, format_error(reason)}
          end
      end
    rescue
      e ->
        Logger.error("Error getting graph data for file #{path}: #{inspect(e)}")
        {:error, "Failed to get graph data for file: #{Exception.message(e)}"}
    end
  end

  # Normalize file paths to ensure consistency
  defp normalize_path(path) do
    # Convert absolute paths to relative from project root
    case Path.type(path) do
      :absolute ->
        # Try to make it relative to the application root
        project_root = Application.app_dir(:graph_os_dev) |> Path.dirname() |> Path.dirname()

        case Path.relative_to(path, project_root) do
          # If unchanged, it wasn't under project_root
          ^path -> path
          relative_path -> relative_path
        end

      # Already relative, return as is
      _ ->
        path
    end
    # Normalize separators for cross-platform consistency
    |> String.replace("\\", "/")
  end

  defp format_error(error) when is_map(error) do
    cond do
      Map.has_key?(error, "message") -> error["message"]
      Map.has_key?(error, :message) -> error.message
      true -> inspect(error)
    end
  end

  defp format_error(error), do: inspect(error)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <.live_component
          module={GraphOS.DevWeb.LiveComponents.GraphIndexLive}
          id="graph-index"
          class=""
        />
      </div>

      <h1 class="text-3xl font-bold mb-8">File Graph Visualization</h1>

      <div class="mb-8">
        <.link navigate={~p"/code-graph"} class="text-blue-500 hover:underline">
          &larr; Back to CodeGraph Dashboard
        </.link>
      </div>

      <div class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Enter File Path</h2>
        <p class="mb-4 text-gray-600">
          Enter the path to a file in the GraphOS codebase to visualize its graph structure.
        </p>

        <.form :let={f} for={%{}} as={:file} phx-submit="search">
          <div class="flex gap-2">
            <div class="flex-1">
              <.input
                field={f[:path]}
                value={@file_path}
                type="text"
                placeholder="apps/graph_os_dev/lib/graph_os_dev/application.ex"
                required
              />
            </div>
            <.button type="submit" class="bg-blue-500 hover:bg-blue-600">
              Visualize
            </.button>
          </div>
        </.form>
      </div>

      <div :if={@loading} class="bg-white p-6 rounded-lg shadow-md mb-8">
        <p class="text-center text-gray-600">Loading graph data...</p>
      </div>

      <div
        :if={@error}
        class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-8"
      >
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline">{format_error(@error)}</span>

        <div class="mt-3 text-sm">
          <p>This could be due to:</p>
          <ul class="list-disc ml-5 mt-1">
            <li>The file path may not match exactly how it's stored in the graph database</li>
            <li>The file may exist but hasn't been indexed in the graph database yet</li>
            <li>The CodeGraph service may not have processed this file</li>
            <li>There may be an issue with the graph query</li>
          </ul>

          <p class="mt-2">Try:</p>
          <ul class="list-disc ml-5 mt-1">
            <li>Checking the file path for typos</li>
            <li>
              Using the relative path from the project root (e.g., <code>apps/graph_os_core/lib/graph_os/core.ex</code>)
            </li>
            <li>
              Verifying the file is within one of the watched directories specified in your configuration
            </li>
            <li>Waiting a moment for any recent changes to be indexed</li>
          </ul>

          <p class="mt-2">
            Current file path: <code class="bg-gray-100 px-2 py-1 rounded">{@file_path}</code>
          </p>
        </div>
      </div>

      <div :if={@graph_data && !@loading} class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Graph for {@file_path}</h2>

        <div id="graph-container" class="w-full h-[600px] border border-gray-300 rounded">
          <p class="text-center text-gray-600 p-4">
            Graph visualization would be displayed here. <br />
            <br />
            <span class="text-sm">
              This is a placeholder. In a real implementation, we would use a JavaScript
              graph visualization library like Cytoscape.js or D3.js to render the graph.
            </span>
          </p>

          <div class="p-4 border-t border-gray-300 mt-4">
            <h3 class="font-semibold mb-2">Raw Graph Data:</h3>
            <pre class="bg-gray-100 p-4 rounded overflow-auto max-h-72"><%= Jason.encode!(@graph_data, pretty: true) %></pre>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
