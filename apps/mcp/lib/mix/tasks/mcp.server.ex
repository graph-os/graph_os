defmodule Mix.Tasks.Mcp.Server do
  @moduledoc """
  A mix task to manage the MCP server in persistent tmux sessions.

  This task provides commands to start, stop, restart, check status, and join
  the MCP server running in a tmux session. It ensures only one server
  instance is running at a time.

  ## Commands

    * `start` - Start the MCP server in a tmux session if not already running
    * `stop` - Stop the running MCP server
    * `restart` - Restart the MCP server
    * `status` - Check if the MCP server is running
    * `join` - Join the tmux session of a running server
    * `start_and_join` - Start the server and immediately join the tmux session

  ## Examples

      # Start the server
      mix mcp.server start

      # Check server status
      mix mcp.server status

      # Join the server session
      mix mcp.server join

      # Stop the server
      mix mcp.server stop

      # Restart the server
      mix mcp.server restart

      # Start and join the server in one command
      mix mcp.server start_and_join
  """

  use TMUX.Task,
    key: "graph_os_mcp_server",
    cwd: "#{File.cwd!()}",
    on_run: [],
    env: %{
      "MIX_ENV" => "dev",
      "MCP_DEBUG" => "true"
    }

  # Implementation for when the task runs directly (when tmux is not available)
  # or within the tmux session
  defp run_implementation(_args) do
    Mix.shell().info("Starting MCP server...")

    # Configure the application
    Application.put_env(:mcp, MCP, [log_level: :debug])

    # Start the application and its dependencies
    Application.ensure_all_started(:mcp)

    # Keep the process running
    Process.sleep(:infinity)
  end

  # Override the standard run method to add our custom commands
  @impl Mix.Task
  def run(args) do
    if args == ["start_and_join"] do
      handle_start_and_join()
    else
      super(args)
    end
  end

  defp handle_start_and_join do
    Mix.shell().info("Starting MCP server and joining the session...")

    # Start the server if not already running
    if !TMUX.session_exists?(@session_name) do
      handle_start()
      # Wait a short time for the server to initialize
      :timer.sleep(2000)
    end

    # Join the session if the server is running
    if TMUX.session_exists?(@session_name) do
      handle_join()
    else
      Mix.shell().error("Failed to start MCP server!")
      exit({:shutdown, 1})
    end
  end
end
