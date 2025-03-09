defmodule GraphOS.DevWeb.Components.GraphIndexComponent do
  @moduledoc """
  A reusable component that displays graph indexing status and controls.
  Similar to the Cursor Indexing UI, this component shows:
  - Current indexing status
  - Progress indicator
  - Resync and delete index controls
  """
  use Phoenix.Component
  require Logger

  attr :class, :string, default: ""

  def graph_index(assigns) do
    # Get the current status from the CodeGraph service
    graph_status = case get_graph_status() do
      {:ok, status} -> status
      {:error, _} -> %{
        modules: 0,
        functions: 0,
        files: 0,
        last_update: nil
      }
    end

    # Update assigns with current status
    assigns = assign(assigns,
      graph_status: graph_status,
      synced_percentage: calculate_percentage(graph_status),
      synced_label: "Synced",
      show_settings: false
    )

    ~H"""
    <div class={"bg-gray-800 text-white p-6 rounded-md #{@class}"}>
      <h2 class="text-2xl mb-6">Graph Indexing</h2>
      <p class="text-gray-400 mb-6">
        Embeddings improve your codebase-wide graph analysis. Embeddings and metadata are stored in the graph database.
      </p>

      <div class="mb-4">
        <div class="flex justify-between mb-2">
          <span><%= @synced_label %></span>
          <span><%= @synced_percentage %>%</span>
        </div>
        <div class="h-2 w-full bg-gray-600 rounded-full overflow-hidden">
          <div
            class="h-full bg-blue-500 rounded-full"
            style={"width: #{@synced_percentage}%"}>
          </div>
        </div>
      </div>

      <div class="flex gap-4 mb-6">
        <button
          class="flex items-center px-4 py-2 bg-teal-700 hover:bg-teal-600 text-white rounded transition"
          phx-click="resync_graph_index"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          Resync Index
        </button>

        <button
          class="flex items-center px-4 py-2 bg-transparent hover:bg-gray-700 text-white rounded border border-gray-600 transition"
          phx-click="delete_graph_index"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
          </svg>
          Delete Index
        </button>
      </div>

      <button
        class="flex items-center text-gray-400 hover:text-white"
        phx-click="toggle_graph_settings"
      >
        <svg
          class={"w-5 h-5 mr-2 transform transition-transform #{if @show_settings, do: "rotate-180"}"}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
        Show Settings
      </button>

      <%= if @show_settings do %>
        <div class="mt-4 p-4 bg-gray-700 rounded-md">
          <h3 class="text-lg font-medium mb-2">Indexing Statistics</h3>
          <dl class="grid grid-cols-2 gap-2">
            <dt class="text-gray-400">Modules indexed:</dt>
            <dd><%= @graph_status.modules %></dd>

            <dt class="text-gray-400">Functions indexed:</dt>
            <dd><%= @graph_status.functions %></dd>

            <dt class="text-gray-400">Files indexed:</dt>
            <dd><%= @graph_status.files %></dd>

            <dt class="text-gray-400">Last updated:</dt>
            <dd><%= format_datetime(@graph_status.last_update) %></dd>
          </dl>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp get_graph_status do
    case Process.whereis(GraphOS.Core.CodeGraph.Service) do
      nil ->
        Logger.warning("CodeGraph.Service is not running.")
        {:error, "Service not available"}

      _pid ->
        GraphOS.Core.CodeGraph.Service.status()
    end
  end

  defp calculate_percentage(status) do
    # A simple algorithm to calculate completion percentage
    # This is just an example - you may want to use a more sophisticated approach
    cond do
      status.modules == 0 and status.functions == 0 and status.files == 0 ->
        0

      status.last_update == nil ->
        50  # In progress but no last update time

      true ->
        100 # Consider it complete if we have data and a last update time
    end
  end

  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    # Format the datetime for display
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
