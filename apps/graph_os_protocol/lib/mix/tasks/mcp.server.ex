defmodule Mix.Tasks.Graphos.Mcp.Server do
  @moduledoc """
  Starts the GraphOS MCP server applications, including the web server.
  """
  use Mix.Task

  @shortdoc "Starts the GraphOS MCP server applications"
  def run(_args) do
    # Ensure apps are compiled and loaded (Mix does this implicitly)
    IO.puts("Starting required applications...")
    # Starting :graph_os_protocol will start its dependencies and its own supervision tree,
    # which now includes Bandit configured with GraphOS.Protocol.Router.
    Application.ensure_all_started(:graph_os_protocol)
    IO.puts("Applications started.")

    port = Application.get_env(:bandit, :port, 4000) # Get configured port
    IO.puts("GraphOS MCP Server potentially running via SSE on port #{port}.")

    # Keep the task running so the applications don't stop
    IO.puts("Task sleeping indefinitely...")
    Process.sleep(:infinity)
  end
end
