defmodule GraphOS.DevWeb.GraphLive.File do
  @moduledoc """
  LiveView for file-based CodeGraph visualization.

  This view allows visualizing the graph structure of a specific file.
  """
  use GraphOS.DevWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "File CodeGraph Visualization",
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
    # Directly use the GraphController's helper function to get file data
    # This avoids an unnecessary HTTP request
    try do
      # Check if the CodeGraph service is running
      case Process.whereis(GraphOS.Core.CodeGraph.Service) do
        nil ->
          # Service is not running
          Logger.warning("CodeGraph.Service is not running. Unable to fetch file data.")
          {:error, "CodeGraph service not available. Please ensure it's enabled in your configuration."}

        _pid ->
          # Use the Graph.Query module to get file data
          query_module = Application.get_env(:graph_os_mcp, :query_module, GraphOS.Graph.Query)

          # Fetch nodes and edges associated with this file
          case query_module.execute(start_node_id: path, depth: 2) do
            {:ok, results} -> {:ok, %{nodes: results}}
            {:error, reason} ->
              # Format the error message
              {:error, format_error(reason)}
          end
      end
    rescue
      e ->
        Logger.error("Error getting graph data for file #{path}: #{inspect(e)}")
        {:error, "Failed to get graph data for file: #{Exception.message(e)}"}
    end
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
      <h1 class="text-3xl font-bold mb-8">File CodeGraph Visualization</h1>

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
              <.input field={f[:path]} value={@file_path} type="text" placeholder="apps/graph_os_mcp/lib/graph_os/mcp/application.ex" required />
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

      <div :if={@error} class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-8">
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline"><%= format_error(@error) %></span>
      </div>

      <div :if={@graph_data && !@loading} class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Graph for <%= @file_path %></h2>

        <div id="graph-container" class="w-full h-[600px] border border-gray-300 rounded">
          <p class="text-center text-gray-600 p-4">
            Graph visualization would be displayed here.
            <br />
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
