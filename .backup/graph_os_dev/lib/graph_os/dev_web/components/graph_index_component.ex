defmodule GraphOS.DevWeb.GraphIndexComponent do
  use GraphOS.DevWeb, :live_component
  require Logger

  alias GraphOS.Dev.CodeGraph.Service, as: CodeGraphService

  @impl true
  def render(assigns) do
    ~H"""
    <div class="graph-index">
      <%= if @status do %>
        <div class="stats">
          <p>Modules: {@status.modules}</p>
          <p>Functions: {@status.functions}</p>
          <p>Relationships: {@status.relationships}</p>
          <p>Files: {@status.files_tracked}</p>
          <%= if @status.last_update do %>
            <p>Last Update: {@status.last_update}</p>
          <% end %>
        </div>
      <% else %>
        <p>No status available</p>
      <% end %>

      <%= if @error do %>
        <div class="error">
          {@error}
        </div>
      <% end %>

      <button phx-click="rebuild" phx-target={@myself}>Rebuild Graph</button>
    </div>
    """
  end

  @impl true
  def handle_event("rebuild", _params, socket) do
    case Process.whereis(CodeGraphService) do
      nil ->
        {:noreply, assign(socket, error: "CodeGraph service not available")}

      _pid ->
        case CodeGraphService.status() do
          {:ok, status} ->
            {:noreply, assign(socket, status: status, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, error: "Failed to get status: #{inspect(reason)}")}
        end
    end
  end
end
