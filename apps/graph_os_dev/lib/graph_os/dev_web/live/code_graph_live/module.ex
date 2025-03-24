defmodule GraphOS.DevWeb.CodeGraphLive.Module do
  @moduledoc """
  LiveView for module-based code graph visualization.

  This view allows visualizing the graph structure of a specific module.

  This LiveView directly accesses the CodeGraph service rather than going through the API,
  providing more efficient access to graph data.
  """
  use GraphOS.DevWeb, :live_view
  require Logger

  alias GraphOS.Dev.CodeGraph.Service, as: CodeGraphService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Module Graph Visualization",
       module_name: "",
       graph_data: nil,
       loading: false,
       error: nil
     )}
  end

  @impl true
  def handle_params(%{"name" => name}, _url, socket) when is_binary(name) and name != "" do
    # Fetch graph data for this module
    send(self(), {:fetch_graph_data, name})

    {:noreply, assign(socket, module_name: name, loading: true)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"module" => %{"name" => name}}, socket) do
    # Redirect to the same page with the module name as a query parameter
    # This allows bookmarking and sharing specific module views
    {:noreply, push_patch(socket, to: ~p"/code-graph/module?name=#{name}")}
  end

  @impl true
  def handle_info({:fetch_graph_data, name}, socket) do
    case fetch_graph_data(name) do
      {:ok, data} ->
        {:noreply, assign(socket, graph_data: data, loading: false, error: nil)}

      {:error, error} ->
        {:noreply, assign(socket, loading: false, error: error, graph_data: nil)}
    end
  end

  defp fetch_graph_data(name) do
    # Instead of making an HTTP request, directly access the CodeGraph service
    # This is more efficient and avoids the overhead of HTTP requests
    Logger.debug("Directly accessing CodeGraph service for module #{name}")

    # Check if the CodeGraph service is running
    case Process.whereis(CodeGraphService) do
      nil ->
        # Service is not running
        Logger.warning("CodeGraph.Service is not running. Unable to fetch module data.")

        {:error,
         "CodeGraph service not available. Please ensure it's enabled in your configuration."}

      _pid ->
        # Service is running, try to query it
        case CodeGraphService.query_module(name) do
          {:ok, module_info} ->
            # Transform the module info into a format suitable for visualization
            {:ok, transform_module_info_for_visualization(module_info)}

          {:error, reason} ->
            Logger.warning("Error querying CodeGraph service: #{inspect(reason)}")
            {:error, format_error(reason)}
        end
    end
  end

  # Transform module info from CodeGraph.Service into visualization format
  defp transform_module_info_for_visualization(module_info) do
    # Extract nodes and edges from the module info
    # This is a simplified implementation - we may need to adjust based on the actual data structure
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

  defp format_error(error) when is_map(error) do
    cond do
      Map.has_key?(error, "message") -> error["message"]
      Map.has_key?(error, :message) -> error.message
      true -> inspect(error)
    end
  end

  defp format_error(error), do: inspect(error)

  # Template for rendering the error message
  defp render_error(assigns) do
    ~H"""
    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-8">
      <strong class="font-bold">Error:</strong>
      <span class="block sm:inline">{format_error(@error)}</span>

      <div class="mt-2 text-sm">
        <p>This could be due to:</p>
        <ul class="list-disc ml-5 mt-1">
          <li>The module doesn't exist in the codebase</li>
          <li>The module exists but hasn't been indexed in the graph database</li>
          <li>The CodeGraph service is not running or is not configured properly</li>
          <li>There was an issue with the graph query</li>
        </ul>
        <p class="mt-2">Try checking the module name for typos or try a different module.</p>

        <p :if={@error =~ "CodeGraph service not available"} class="mt-2 font-semibold">
          The CodeGraph service needs to be enabled in your configuration: <br /><br />
          <code class="bg-gray-800 text-white p-2 rounded block">
            # In config/dev.exs
            config :graph_os_core,
            enable_code_graph: true,
            watch_directories: ["apps/graph_os_core/lib", ...]
          </code>
        </p>
      </div>
    </div>
    """
  end

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

      <h1 class="text-3xl font-bold mb-8">Module Graph Visualization</h1>

      <div class="mb-8">
        <.link navigate={~p"/code-graph"} class="text-blue-500 hover:underline">
          &larr; Back to Graph Dashboard
        </.link>
      </div>

      <div class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Enter Module Name</h2>
        <p class="mb-4 text-gray-600">
          Enter the name of a module in the GraphOS codebase to visualize its graph structure.
        </p>

        <.form :let={f} for={%{}} as={:module} phx-submit="search">
          <div class="flex gap-2">
            <div class="flex-1">
              <.input
                field={f[:name]}
                value={@module_name}
                type="text"
                placeholder="GraphOS.MCP.Application"
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

      <.render_error :if={@error} error={@error} />

      <div :if={@graph_data && !@loading} class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Graph for {@module_name}</h2>

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
