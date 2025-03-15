defmodule GraphOS.DevWeb.CodeGraphLive.Index do
  @moduledoc """
  LiveView for CodeGraph visualization dashboard.

  This is the main entry point for code graph visualization features.
  """
  use GraphOS.DevWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Fetch lists of files and modules when the component mounts
    send(self(), :fetch_lists)

    {:ok, assign(socket,
      page_title: "Graph Visualization",
      search_query: "",
      search_results: [],
      selected_index: nil,
      files: [],
      modules: [],
      loading: true,
      error: nil,
      graph_data: nil,
      active_tab: "search",
      stats: %{
        indexed_modules: 0,
        indexed_functions: 0,
        indexed_files: 0
      }
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Graph Visualization")
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
  def handle_event("set_active_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_info(:fetch_lists, socket) do
    case fetch_files_and_modules() do
      {:ok, %{files: files, modules: modules, stats: stats}} ->
        {:noreply, assign(socket, files: files, modules: modules, stats: stats, loading: false, error: nil)}
      {:ok, %{"files" => files, "modules" => modules, "stats" => stats}} ->
        # Handle response with string keys (from JSON)
        {:noreply, assign(socket, files: files, modules: modules, stats: stats, loading: false, error: nil)}
      {:ok, %{files: files, modules: modules}} ->
        # Backward compatibility
        {:noreply, assign(socket, files: files, modules: modules, loading: false, error: nil)}
      {:ok, %{"files" => files, "modules" => modules}} ->
        # Backward compatibility with string keys
        {:noreply, assign(socket, files: files, modules: modules, loading: false, error: nil)}
      {:error, error} ->
        {:noreply, assign(socket, loading: false, error: error)}
    end
  end

  defp fetch_files_and_modules do
    try do
      # Make API request to the CodeGraphController endpoint
      url = GraphOS.DevWeb.Endpoint.url() <> "/api/code-graph/list"

      case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
        {:ok, {{_, 200, _}, _, body}} ->
          # Parse JSON response
          {:ok, decoded} = Jason.decode(to_string(body))
          {:ok, decoded}

        {:ok, {{_, status, _}, _, body}} ->
          Logger.error("Failed to fetch files and modules. Status: #{status}, Body: #{body}")
          {:error, "Failed to fetch data (status #{status})"}

        {:error, reason} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, "Failed to make HTTP request: #{inspect(reason)}"}
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
      <div class="mb-6">
        <.live_component
          module={GraphOS.DevWeb.LiveComponents.GraphIndexLive}
          id="graph-index"
          class=""
        />
      </div>

      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Code Graph Explorer</h1>
        <div class="flex items-center space-x-4">
          <div class="stats bg-gray-100 p-2 rounded-lg text-sm inline-flex items-center space-x-4">
            <div class="stat flex items-center space-x-1">
              <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
              </svg>
              <span><%= @stats.indexed_modules %> modules</span>
            </div>
            <div class="stat flex items-center space-x-1">
              <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"></path>
              </svg>
              <span><%= @stats.indexed_functions %> functions</span>
            </div>
            <div class="stat flex items-center space-x-1">
              <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
              <span><%= @stats.indexed_files %> files</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="mb-8">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8">
            <a 
              href="#" 
              class={"pb-4 px-1 font-medium text-sm border-b-2 transition-colors duration-200 ease-out 
                #{if @active_tab == "search", do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"} 
              phx-click="set_active_tab" 
              phx-value-tab="search"
            >
              <div class="flex items-center">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
                Search
              </div>
            </a>
            <a 
              href="#" 
              class={"pb-4 px-1 font-medium text-sm border-b-2 transition-colors duration-200 ease-out 
                #{if @active_tab == "modules", do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"} 
              phx-click="set_active_tab" 
              phx-value-tab="modules"
            >
              <div class="flex items-center">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"></path>
                </svg>
                Modules
              </div>
            </a>
            <a 
              href="#" 
              class={"pb-4 px-1 font-medium text-sm border-b-2 transition-colors duration-200 ease-out 
                #{if @active_tab == "files", do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"} 
              phx-click="set_active_tab" 
              phx-value-tab="files"
            >
              <div class="flex items-center">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                Files
              </div>
            </a>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="min-h-[600px]">
        <%= case @active_tab do %>
          <% "search" -> %>
            <!-- Search Component -->
            <div class="bg-white p-6 rounded-lg shadow-md mb-8">
              <div class="flex items-center mb-4 text-gray-600">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <p>Search for files or modules to visualize. Files typically start with lowercase, modules with uppercase.</p>
              </div>

              <.form :let={f} for={%{}} as={:search} phx-submit="search" phx-change="search">
                <div class="relative">
                  <div class="flex gap-2">
                    <div class="flex-1 relative">
                      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                        </svg>
                      </div>
                      <.input
                        field={f[:query]}
                        value={@search_query}
                        type="text"
                        placeholder="Type to search files or modules..."
                        phx-keydown="key_down"
                        autocomplete="off"
                        class="pl-10"
                      />
                    </div>
                    <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700">
                      Search
                    </.button>
                  </div>

                  <!-- Search Results Dropdown -->
                  <%= if @search_query != "" and length(@search_results) > 0 do %>
                    <div class="absolute mt-1 w-full bg-white border border-gray-300 rounded-md shadow-lg z-10">
                      <ul class="max-h-60 overflow-auto py-1">
                        <%= for {result, index} <- Enum.with_index(@search_results) do %>
                          <li
                            class={"px-4 py-2 cursor-pointer hover:bg-gray-100 #{if index == @selected_index, do: "bg-indigo-50", else: ""}"}
                            phx-click="navigate_to"
                            phx-value-type={result.type}
                            phx-value-path={result[:path]}
                            phx-value-name={result[:name]}
                          >
                            <div class="flex items-center">
                              <%= if result.type == "file" do %>
                                <span class="mr-2 text-xs px-1.5 py-0.5 rounded bg-green-100 text-green-800 flex items-center">
                                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                                  </svg>
                                  File
                                </span>
                              <% else %>
                                <span class="mr-2 text-xs px-1.5 py-0.5 rounded bg-purple-100 text-purple-800 flex items-center">
                                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
                                  </svg>
                                  Module
                                </span>
                              <% end %>
                              <span class="text-sm font-medium"><%= result.display %></span>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>
                </div>
              </.form>

              <%= if @search_query != "" and length(@search_results) == 0 do %>
                <div class="mt-4 text-center py-8 bg-gray-50 rounded-lg border border-gray-200">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No results found</h3>
                  <p class="mt-1 text-sm text-gray-500">Try adjusting your search terms</p>
                </div>
              <% end %>
            </div>

            <!-- Recent Visualizations (placeholder) -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Recently Viewed</h2>
              <p class="text-gray-500 italic text-sm">History will appear here as you explore the codebase</p>
            </div>

          <% "modules" -> %>
            <!-- Modules List -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Modules</h2>
                <span class="text-sm bg-purple-100 text-purple-800 py-1 px-2 rounded-full"><%= length(@modules) %> total</span>
              </div>
              
              <%= if @loading do %>
                <div class="flex justify-center items-center py-16">
                  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-500"></div>
                </div>
              <% else %>
                <%= if @error do %>
                  <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
                    <div class="flex">
                      <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                      </svg>
                      <p><%= format_error(@error) %></p>
                    </div>
                  </div>
                <% else %>
                  <div class="overflow-y-auto max-h-[600px] pr-2">
                    <ul class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                      <%= for module <- @modules do %>
                        <li>
                          <.link
                            navigate={~p"/code-graph/module?name=#{module}"}
                            class="block py-2 px-3 rounded border border-gray-200 hover:bg-purple-50 hover:border-purple-200 transition-colors text-purple-700 hover:text-purple-900"
                          >
                            <div class="flex items-center">
                              <div class="mr-2 p-1 rounded-md bg-purple-100">
                                <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
                                </svg>
                              </div>
                              <span class="text-sm truncate"><%= module %></span>
                            </div>
                          </.link>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              <% end %>
            </div>

          <% "files" -> %>
            <!-- Files List -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Files</h2>
                <span class="text-sm bg-green-100 text-green-800 py-1 px-2 rounded-full"><%= length(@files) %> total</span>
              </div>
              
              <%= if @loading do %>
                <div class="flex justify-center items-center py-16">
                  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-500"></div>
                </div>
              <% else %>
                <%= if @error do %>
                  <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
                    <div class="flex">
                      <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                      </svg>
                      <p><%= format_error(@error) %></p>
                    </div>
                  </div>
                <% else %>
                  <div class="overflow-y-auto max-h-[600px] pr-2">
                    <ul class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                      <%= for file <- @files do %>
                        <li>
                          <.link
                            navigate={~p"/code-graph/file?path=#{file}"}
                            class="block py-2 px-3 rounded border border-gray-200 hover:bg-green-50 hover:border-green-200 transition-colors text-green-700 hover:text-green-900"
                          >
                            <div class="flex items-center">
                              <div class="mr-2 p-1 rounded-md bg-green-100">
                                <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                                </svg>
                              </div>
                              <span class="text-sm truncate"><%= file %></span>
                            </div>
                          </.link>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              <% end %>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
