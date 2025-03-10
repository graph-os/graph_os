defmodule Mix.Tasks.Mcp.Debug do
  @moduledoc """
  Starts the MCP server with debug mode enabled.

  This task starts the MCP endpoint with debugging enabled, exposing
  JSON-based endpoints (no HTML/JS interfaces).

  ## Usage

      mix mcp.debug [--port PORT]

  ## Options

    * `--port` - The port to run the server on (default: 4000)
  """

  use TMUX.Task,
    key: "graph_os_mcp_debug",
    cwd: "#{File.cwd!()}",
    on_run: [:start],
    env: %{
      "MIX_ENV" => "dev",
      "MCP_DEBUG" => "true"
    }

  @shortdoc "Starts the MCP server with debug mode (JSON only)"

  # Override the run method to parse arguments before passing to super
  @impl Mix.Task
  def run(args) do
    # Parse command line arguments
    {opts, remaining_args, _} = OptionParser.parse(args, strict: [port: :integer])

    # Store the port in the process dictionary for use in run_implementation
    port = Keyword.get(opts, :port, 4000)
    Process.put(:mcp_port, port)

    # Call parent implementation which will manage the tmux session
    super(remaining_args)
  end

  # Implementation for when the task runs directly or in the tmux session.
  # This function is called by the parent TMUX.Task module and handles the actual
  # server startup with the configured port and debug settings.
  @spec run_implementation(any()) :: no_return()
  defp run_implementation(_args) do
    # Get the port from the process dictionary
    port = Process.get(:mcp_port, 4000)

    # Ensure all applications are started
    Mix.Task.run("app.start")

    # Configure debug log level
    Application.put_env(:mcp, MCP, log_level: :debug)

    # Start additional dependencies
    {:ok, _} = Application.ensure_all_started(:bandit)

    # Log startup info
    Mix.shell().info("""
    Starting MCP Debug Server...
      * SSE endpoint: http://localhost:#{port}/sse
      * JSON-RPC endpoint: http://localhost:#{port}/rpc
      * Debug endpoints:
        - http://localhost:#{port}/debug/:session_id
        - http://localhost:#{port}/debug/sessions
        - http://localhost:#{port}/debug/api

    Debug mode enabled (JSON API only).
    Press Ctrl+C twice to stop.
    """)

    # Start the endpoint in debug mode
    {:ok, _pid} = MCP.Endpoint.start_link(debug: true, port: port)

    # Keep the VM running
    Process.sleep(:infinity)
  end
end
