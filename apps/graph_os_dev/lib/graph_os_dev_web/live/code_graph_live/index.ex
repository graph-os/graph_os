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
      active_tab: "search"
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

      <h1 class="text-3xl font-bold mb-8">Graph Visualization</h1>

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
            <%= if @search_query != "" and length(@search_results) > 0 do %>
              <div class="absolute mt-1 w-full bg-white border border-gray-300 rounded-md shadow-lg z-10">
                <ul class="max-h-60 overflow-auto py-1">
                  <%= for {result, index} <- Enum.with_index(@search_results) do %>
                    <li
                      class={"px-4 py-2 cursor-pointer hover:bg-gray-100 #{if index == @selected_index, do: "bg-blue-100", else: ""}"}
                      phx-click="navigate_to"
                      phx-value-type={result.type}
                      phx-value-path={result[:path]}
                      phx-value-name={result[:name]}
                    >
                      <div class="flex items-center">
                        <span class={"mr-2 text-xs px-1.5 py-0.5 rounded #{if result.type == "file", do: "bg-green-100 text-green-800", else: "bg-purple-100 text-purple-800"}"}>
                          <%= result.type %>
                        </span>
                        <span><%= result.display %></span>
                      </div>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        </.form>
      </div>

      <!-- Display area for modules and files -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <!-- Modules List -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h2 class="text-xl font-semibold mb-4">Modules</h2>
          <%= if @loading do %>
            <div class="flex justify-center items-center py-8">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          <% else %>
            <%= if @error do %>
              <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
                <p><%= format_error(@error) %></p>
              </div>
            <% else %>
              <div class="overflow-y-auto max-h-[400px] pr-2">
                <ul class="space-y-1">
                  <%= for module <- @modules do %>
                    <li>
                      <.link
                        navigate={~p"/code-graph/module?name=#{module}"}
                        class="block py-2 px-3 rounded hover:bg-gray-100 text-blue-600 hover:text-blue-800"
                      >
                        <%= module %>
                      </.link>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Files List -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h2 class="text-xl font-semibold mb-4">Files</h2>
          <%= if @loading do %>
            <div class="flex justify-center items-center py-8">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          <% else %>
            <%= if @error do %>
              <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
                <p><%= format_error(@error) %></p>
              </div>
            <% else %>
              <div class="overflow-y-auto max-h-[400px] pr-2">
                <ul class="space-y-1">
                  <%= for file <- @files do %>
                    <li>
                      <.link
                        navigate={~p"/code-graph/file?path=#{file}"}
                        class="block py-2 px-3 rounded hover:bg-gray-100 text-green-600 hover:text-green-800"
                      >
                        <%= file %>
                      </.link>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
