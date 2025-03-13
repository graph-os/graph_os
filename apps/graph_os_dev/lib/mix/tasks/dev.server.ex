defmodule Mix.Tasks.Dev.Server do
  @moduledoc """
  A mix task to manage the Phoenix development server in persistent tmux sessions.

  This task provides commands to start, stop, restart, check status, and join
  the Phoenix server running in a tmux session. It ensures only one server
  instance is running at a time.

  The server includes both the Phoenix web application and the MCP server for AI/LLM integration.
  MCP is integrated directly in the Phoenix application and accessible via /mcp routes.

  ## Commands

    * `start` - Start the Phoenix server in a tmux session if not already running
    * `stop` - Stop the running Phoenix server
    * `restart` - Restart the Phoenix server
    * `status` - Check if the Phoenix server is running
    * `join` - Join the tmux session of a running server
    * `direct` - Run the server directly without tmux

  ## Options

    * `--port` - Specify the port to run the Phoenix server on (default: 4000)

  ## Examples

      # Start the server
      mix dev.server start

      # Start the server on a specific port
      mix dev.server start --port 4001

      # Check server status
      mix dev.server status

      # Join the server session
      mix dev.server join

      # Stop the server
      mix dev.server stop

      # Restart the server
      mix dev.server restart

      # Run the server directly (without tmux)
      mix dev.server direct
  """

  @shortdoc "Starts the Phoenix server in a tmux session"

  use TMUX.Task,
    key: "dev_server",
    cwd: "#{File.cwd!()}",
    on_run: [:start],
    env: %{
      "MIX_ENV" => "dev"
    }

  @impl Mix.Task
  def run(args) do
    # Parse command line arguments for port
    {opts, remaining_args, _} = OptionParser.parse(args, strict: [port: :integer])

    # Store the port in the process dictionary for use in run_implementation
    port = Keyword.get(opts, :port, 4000)
    Process.put(:dev_server_port, port)

    # Handle direct command (run without tmux)
    if List.first(remaining_args) == "direct" do
      Mix.shell().info("Starting GraphOS Development server directly...")
      run_implementation(remaining_args)
    else
      # Call parent implementation which will manage the tmux session
      super(remaining_args)
    end
  end

  # Implementation for when the task runs directly (when tmux is not available)
  # or within the tmux session
  defp run_implementation(_args) do
    Mix.shell().info("Starting GraphOS Development server...")
    port = Process.get(:dev_server_port, 4000)

    # Set the Phoenix server port via environment variable
    System.put_env("PORT", Integer.to_string(port))

    # Configure the Phoenix endpoint with the specified port
    Application.put_env(:graph_os_dev, GraphOSDevWeb.Endpoint,
      http: [port: port],
      server: true)

    # Explicitly set server to true for the endpoint
    Application.put_env(:phoenix, :serve_endpoints, true)

    # Start the Phoenix server directly
    Mix.shell().info("Starting Phoenix server on port #{port}...")

    # Use phx.server task which properly starts the server
    Mix.Task.run("phx.server")

    # Keep the process running
    Process.sleep(:infinity)
  end
end
