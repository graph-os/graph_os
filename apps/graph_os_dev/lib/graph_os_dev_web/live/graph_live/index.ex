defmodule GraphOS.DevWeb.GraphLive.Index do
  @moduledoc """
  LiveView for CodeGraph visualization dashboard.

  This is the main entry point for code graph visualization features.
  """
  use GraphOS.DevWeb, :live_view
  import GraphOS.DevWeb.Components.GraphIndexComponent
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Fetch lists of files and modules when the component mounts
    send(self(), :fetch_lists)

    {:ok, assign(socket,
      page_title: "CodeGraph Visualization",
      search_query: "",
      search_results: [],
      selected_index: nil,
      files: [],
      modules: [],
      loading: true,
      error: nil
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "CodeGraph Visualization")
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) when byte_size(query) > 0 do
    search_results = perform_search(query, socket.assigns.files, socket.assigns.modules)
    {:noreply, assign(socket, search_query: query, search_results: search_results, selected_index: nil)}
  end

  @impl true
  def handle_event("search", _params, socket) do
    {:noreply, assign(socket, search_query: "", search_results: [], selected_index: nil)}
  end

  @impl true
  def handle_event("navigate_to", %{"type" => "file", "path" => path}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/code-graph/file?path=#{path}")}
  end

  @impl true
  def handle_event("navigate_to", %{"type" => "module", "name" => name}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/code-graph/module?name=#{name}")}
  end

  @impl true
  def handle_event("key_down", %{"key" => "ArrowDown"}, socket) do
    # Handle arrow down navigation in search results
    current_index = socket.assigns[:selected_index] || -1
    max_index = length(socket.assigns.search_results) - 1

    # Only update if there are search results
    if max_index >= 0 do
      new_index = min(current_index + 1, max_index)
      {:noreply, assign(socket, selected_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("key_down", %{"key" => "ArrowUp"}, socket) do
    # Handle arrow up navigation in search results
    current_index = socket.assigns[:selected_index] || 0

    # Only update if there are search results
    if length(socket.assigns.search_results) > 0 do
      new_index = max(current_index - 1, 0)
      {:noreply, assign(socket, selected_index: new_index)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("key_down", %{"key" => "Enter"}, socket) do
    # Handle enter key to navigate to the selected result
    case socket.assigns do
      %{selected_index: index, search_results: results} when is_integer(index) and index >= 0 and index < length(results) ->
        selected_result = Enum.at(results, index)

        case selected_result do
          %{type: "file", path: path} ->
            {:noreply, push_navigate(socket, to: ~p"/code-graph/file?path=#{path}")}
          %{type: "module", name: name} ->
            {:noreply, push_navigate(socket, to: ~p"/code-graph/module?name=#{name}")}
          _ ->
            {:noreply, socket}
        end
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("key_down", _params, socket) do
    # Catch-all clause for any other key events
    {:noreply, socket}
  end

  @impl true
  def handle_info(:fetch_lists, socket) do
    case fetch_files_and_modules() do
      {:ok, %{files: files, modules: modules}} ->
        {:noreply, assign(socket, files: files, modules: modules, loading: false, error: nil)}
      {:ok, %{"files" => files, "modules" => modules}} ->
        # Handle response with string keys (from JSON)
        {:noreply, assign(socket, files: files, modules: modules, loading: false, error: nil)}
      {:error, error} ->
        {:noreply, assign(socket, loading: false, error: error)}
    end
  end

  defp fetch_files_and_modules do
    # Directly use the GraphController's function to get files and modules
    # This avoids an unnecessary HTTP request
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
              # Use the GraphOS.Graph.Query to get all nodes
              # Query all nodes and filter by type
              case GraphOS.Graph.Query.find_nodes_by_properties(%{}) do
                {:ok, nodes} ->
                  # Extract files and modules from nodes
                  {files, modules} = Enum.reduce(nodes, {[], []}, fn node, {files_acc, modules_acc} ->
                    properties = Map.get(node, :properties, %{})

                    cond do
                      # If node has a file property and no module property, it's a file
                      Map.has_key?(properties, :file) and not Map.has_key?(properties, :module) ->
                        {[properties.file | files_acc], modules_acc}

                      # If node has an id that looks like a module (contains dots, starts with uppercase)
                      node.id =~ ~r/^[A-Z].*\..*/ ->
                        {files_acc, [node.id | modules_acc]}

                      # Otherwise, don't add to either list
                      true ->
                        {files_acc, modules_acc}
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
                  {:error, "Failed to retrieve files and modules from graph"}
              end

            {:error, reason} ->
              Logger.error("Failed to get CodeGraph service status: #{inspect(reason)}")
              {:error, "Failed to communicate with CodeGraph service"}
          end
      end
    rescue
      e ->
        Logger.error("Error in fetch_files_and_modules: #{inspect(e)}")
        {:error, format_error(e)}
    end
  end

  defp perform_search(query, files, modules) do
    query = String.downcase(query)

    # Filter files and modules based on the query using fuzzy matching
    file_results = files
    |> Enum.filter(fn file -> String.contains?(String.downcase(file), query) end)
    |> Enum.map(fn file -> %{type: "file", path: file, display: file} end)
    |> Enum.take(10)  # Limit to 10 results for files

    module_results = modules
    |> Enum.filter(fn module -> String.contains?(String.downcase(module), query) end)
    |> Enum.map(fn module -> %{type: "module", name: module, display: module} end)
    |> Enum.take(10)  # Limit to 10 results for modules

    # Combine and sort results, limited to 20 total
    (file_results ++ module_results)
    |> Enum.sort_by(fn %{display: display} -> String.length(display) end)
    |> Enum.take(20)
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
      <h1 class="text-3xl font-bold mb-8">CodeGraph Visualization</h1>

      <!-- Example of using the graph index component directly in a page -->
      <div class="mb-8 lg:hidden">
        <.graph_index />
      </div>

      <!-- Search Component -->
      <div class="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 class="text-xl font-semibold mb-4">Search Files and Modules</h2>
        <p class="mb-4 text-gray-600">
          Search for files or modules to visualize. Files typically start with lowercase, modules with uppercase.
        </p>

        <.form :let={f} for={%{}} as={:search} phx-submit="search" phx-change="search">
          <div class="relative">
            <div class="flex gap-2">
              <div class="flex-1">
                <.input
                  field={f[:query]}
                  value={@search_query}
                  type="text"
                  placeholder="Type to search files or modules..."
                  phx-keydown="key_down"
                  autocomplete="off"
                />
              </div>
              <.button type="submit" class="bg-blue-500 hover:bg-blue-600">
                Search
              </.button>
            </div>

            <!-- Search Results Dropdown -->
            <div :if={@search_query != "" && @search_results != []} class="absolute z-10 w-full mt-1 bg-white rounded-md shadow-lg max-h-60 overflow-auto">
              <ul class="py-1">
                <%= for {result, index} <- Enum.with_index(@search_results) do %>
                  <li
                    class={"px-4 py-2 cursor-pointer flex justify-between items-center #{if @selected_index == index, do: "bg-blue-100", else: "hover:bg-blue-50"}"}
                    phx-click={
                      case result do
                        %{type: "file", path: path} -> JS.push("navigate_to", value: %{type: "file", path: path})
                        %{type: "module", name: name} -> JS.push("navigate_to", value: %{type: "module", name: name})
                      end
                    }
                  >
                    <span><%= result.display %></span>
                    <span class="text-xs text-gray-500"><%= String.capitalize(result.type) %></span>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </.form>
      </div>

      <!-- Loading State -->
      <div :if={@loading} class="bg-white p-6 rounded-lg shadow-md mb-8">
        <p class="text-center text-gray-600">Loading files and modules...</p>
      </div>

      <!-- Error State -->
      <div :if={@error} class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-8">
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline"><%= format_error(@error) %></span>
      </div>

      <!-- File and Module Lists -->
      <div :if={not @loading and is_nil(@error)} class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Module List -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h2 class="text-xl font-semibold mb-4">Modules</h2>

          <div class="overflow-y-auto max-h-96">
            <ul class="divide-y divide-gray-200">
              <%= for module <- @modules do %>
                <li class="py-2">
                  <.link
                    navigate={~p"/code-graph/module?name=#{module}"}
                    class="text-blue-600 hover:text-blue-800 hover:underline block w-full truncate"
                  >
                    <%= module %>
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
        </div>

        <!-- File List -->
        <div class="order-2 lg:order-1 bg-white p-6 rounded-lg shadow-md">
          <h2 class="text-xl font-semibold mb-4">Files</h2>

          <div class="overflow-y-auto max-h-96">
            <ul class="divide-y divide-gray-200">
              <%= for file <- @files do %>
                <li class="py-2">
                  <.link
                    navigate={~p"/code-graph/file?path=#{file}"}
                    class="text-blue-600 hover:text-blue-800 hover:underline block w-full truncate"
                  >
                    <%= file %>
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
