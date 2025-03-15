defmodule GraphOS.DevWeb.LiveComponents.GraphIndexLive do
  @moduledoc """
  LiveComponent for Graph Indexing status and controls.
  This component handles the interactive elements of the Graph Index Component.
  """
  use GraphOS.DevWeb, :live_component
  require Logger

  @impl true
  def mount(socket) do
    # Subscribe to CodeGraph events to get real-time updates
    if Process.whereis(GraphOS.Core.CodeGraph.Service) do
      :ok = GraphOS.Core.CodeGraph.Service.subscribe([:index_complete])
    end

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    graph_status = get_graph_status()

    socket = socket
      |> assign(assigns)
      |> assign(:graph_status, graph_status)
      |> assign(:synced_percentage, calculate_percentage(graph_status))
      |> assign(:synced_label, get_sync_label(graph_status))
      |> assign(:show_settings, socket.assigns[:show_settings] || false)
      |> assign(:status_color, get_status_color(graph_status))

    {:ok, socket}
  end

  @impl true
  def handle_event("resync_graph_index", _params, socket) do
    # Attempt to rebuild the graph index
    case Process.whereis(GraphOS.Core.CodeGraph.Service) do
      nil ->
        # Service not available
        socket = put_flash(socket, :error, "CodeGraph service is not available")
        {:noreply, socket}

      _pid ->
        # Trigger a rebuild
        :ok = GraphOS.Core.CodeGraph.Service.rebuild()

        # Update the socket with new status (in progress)
        socket = socket
          |> assign(:synced_label, "Indexing...")
          |> assign(:synced_percentage, 50)
          |> assign(:status_color, "bg-yellow-500")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_graph_index", _params, socket) do
    # In a real implementation, this would delete the index
    # For now, we'll just show a message
    socket = put_flash(socket, :info, "Graph index deletion would happen here")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_graph_settings", _params, socket) do
    # Toggle the settings display
    {:noreply, assign(socket, :show_settings, !socket.assigns.show_settings)}
  end

  # This isn't a standard LiveComponent callback, but it's necessary
  # for receiving events from CodeGraphService. The subscription happens
  # in mount/1 above, but the actual event handling happens here.
  #
  # Note: This is technically outside the LiveComponent callback spec,
  # but works in practice because the component process still receives
  # these messages.
  def handle_info({:code_graph_event, :index_complete, status}, socket) do
    # Update the status when indexing completes
    socket = socket
      |> assign(:graph_status, status)
      |> assign(:synced_percentage, 100)
      |> assign(:synced_label, "Synced")
      |> assign(:status_color, "bg-emerald-500")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class={@class}>
      <div class="bg-gradient-to-r from-indigo-900 to-indigo-800 text-white p-6 rounded-xl shadow-lg">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-bold flex items-center">
            <svg class="w-6 h-6 mr-2 text-indigo-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
            </svg>
            Graph Indexing
          </h2>
          
          <div class="flex items-center bg-indigo-950 bg-opacity-50 rounded-full px-3 py-1">
            <div class={"w-2 h-2 rounded-full mr-2 #{@status_color}"}></div>
            <span class="text-xs font-medium"><%= @synced_label %></span>
          </div>
        </div>
        
        <p class="text-indigo-200 text-sm mb-6">
          Graph indexing improves your codebase analysis by building a complete dependency tree of your code. The metadata is stored for fast visualization and exploration.
        </p>

        <div class="mb-6">
          <div class="flex justify-between items-center mb-2 text-xs font-medium">
            <span class="text-indigo-200">Indexed</span>
            <span class="text-indigo-200"><%= @synced_percentage %>%</span>
          </div>
          <div class="h-2 w-full bg-indigo-950 rounded-full overflow-hidden">
            <div
              class={"h-full #{@status_color} rounded-full transition-all duration-500 ease-out"}
              style={"width: #{@synced_percentage}%"}>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-3 gap-3 mb-6 text-center text-xs">
          <div class="bg-indigo-800 bg-opacity-50 p-3 rounded-lg">
            <div class="text-2xl font-bold mb-1 text-white"><%= @graph_status.modules %></div>
            <div class="text-indigo-300">Modules</div>
          </div>
          <div class="bg-indigo-800 bg-opacity-50 p-3 rounded-lg">
            <div class="text-2xl font-bold mb-1 text-white"><%= @graph_status.functions %></div>
            <div class="text-indigo-300">Functions</div>
          </div>
          <div class="bg-indigo-800 bg-opacity-50 p-3 rounded-lg">
            <div class="text-2xl font-bold mb-1 text-white"><%= @graph_status.files %></div>
            <div class="text-indigo-300">Files</div>
          </div>
        </div>

        <div class="flex gap-3 mb-6">
          <button
            class="flex-1 flex items-center justify-center px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg transition"
            phx-click="resync_graph_index"
            phx-target={@myself}
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
            Resync Index
          </button>

          <button
            class="flex items-center justify-center px-4 py-2 bg-transparent hover:bg-indigo-700 text-white rounded-lg border border-indigo-600 transition"
            phx-click="delete_graph_index"
            phx-target={@myself}
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
            </svg>
            Reset
          </button>
        </div>

        <div class="border-t border-indigo-800 pt-4">
          <button
            class="w-full flex items-center justify-between text-indigo-300 hover:text-white text-sm"
            phx-click="toggle_graph_settings"
            phx-target={@myself}
          >
            <span class="font-medium">Details</span>
            <svg
              class={"w-4 h-4 transform transition-transform duration-200 #{if @show_settings, do: "rotate-180"}"}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
            </svg>
          </button>

          <%= if @show_settings do %>
            <div class="mt-4 text-sm">
              <dl class="grid grid-cols-2 gap-2">
                <dt class="text-indigo-300">Last updated:</dt>
                <dd class="text-white"><%= format_datetime(@graph_status.last_update) %></dd>
              </dl>
              
              <div class="mt-3 p-3 bg-indigo-950 bg-opacity-50 rounded text-xs text-indigo-200">
                <p>Graph indexing runs either on demand or when file changes are detected. The graph represents the dependencies between modules, functions, and files in your codebase.</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_graph_status do
    case Process.whereis(GraphOS.Core.CodeGraph.Service) do
      nil ->
        # Return empty status if service is not available
        %{
          modules: 0,
          functions: 0,
          files: 0,
          last_update: nil
        }

      _pid ->
        case GraphOS.Core.CodeGraph.Service.status() do
          {:ok, status} -> status
          {:error, _} ->
            %{
              modules: 0,
              functions: 0,
              files: 0,
              last_update: nil
            }
        end
    end
  end

  defp calculate_percentage(status) do
    # A simple algorithm to calculate completion percentage
    cond do
      status.modules == 0 and status.functions == 0 and status.files == 0 ->
        0

      status.last_update == nil ->
        50  # In progress but no last update time

      true ->
        100 # Consider it complete if we have data and a last update time
    end
  end
  
  defp get_sync_label(status) do
    cond do
      status.modules == 0 and status.functions == 0 and status.files == 0 ->
        "Not indexed"
        
      status.last_update == nil ->
        "Indexing..."
        
      true ->
        "Synced"
    end
  end
  
  defp get_status_color(status) do
    percentage = calculate_percentage(status)
    
    cond do
      percentage == 0 -> "bg-red-500"
      percentage < 100 -> "bg-yellow-500"
      true -> "bg-emerald-500"
    end
  end

  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    # Format the datetime for display
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
