defmodule Mix.Tasks.Protocol.Server do
  @moduledoc """
  A mix task to manage the GraphOS Protocol server in persistent tmux sessions.

  This task provides commands to start, stop, restart, check status, and join
  the Protocol server running in a tmux session. It ensures only one server
  instance is running at a time.

  ## Commands

    * `start` - Start the Protocol server in a tmux session if not already running
    * `stop` - Stop the running Protocol server
    * `restart` - Restart the Protocol server
    * `status` - Check if the Protocol server is running
    * `join` - Join the tmux session of a running server
    * `start_and_join` - Start the server and immediately join the tmux session
    * `direct` - Run the server directly without tmux

  ## Examples

      # Start the server
      mix protocol.server start

      # Check server status
      mix protocol.server status

      # Join the server session
      mix protocol.server join

      # Stop the server
      mix protocol.server stop

      # Restart the server
      mix protocol.server restart

      # Start and join the server in one command
      mix protocol.server start_and_join

      # Run the server directly (without tmux)
      mix protocol.server direct
  """

  use TMUX.Task,
    key: "graph_os_protocol_server",
    cwd: "#{File.cwd!()}",
    on_run: [],
    env: %{
      "MIX_ENV" => "dev"
    }

  # Implementation for when the task runs directly (when tmux is not available)
  # or within the tmux session
  defp run_implementation(_args) do
    Mix.shell().info("Starting GraphOS Protocol server...")

    # Start the application and its dependencies
    Application.ensure_all_started(:graph_os_protocol)

    # Start protocol adapters
    start_protocol_adapters()

    # Keep the process running
    Process.sleep(:infinity)
  end

  # Start all protocol adapters
  defp start_protocol_adapters do
    Mix.shell().info("Starting protocol adapters...")

    # Start JSONRPC adapter
    case GraphOS.Protocol.JSONRPC.start_link(
      name: GraphOS.Protocol.JSONRPCAdapter,
      plugs: [
        # Default auth plug is automatically included unless explicitly disabled
      ]
    ) do
      {:ok, pid} ->
        Mix.shell().info("✅ JSONRPC adapter started (#{inspect pid})")
      {:error, reason} ->
        Mix.shell().error("❌ Failed to start JSONRPC adapter: #{inspect reason}")
    end

    # Start GRPC adapter
    case GraphOS.Protocol.GRPC.start_link(
      name: GraphOS.Protocol.GRPCAdapter
    ) do
      {:ok, pid} ->
        Mix.shell().info("✅ GRPC adapter started (#{inspect pid})")
      {:error, reason} ->
        Mix.shell().error("❌ Failed to start GRPC adapter: #{inspect reason}")
    end

    # Add any other protocol adapters here as needed
  end

  # Override the standard run method to add our custom commands
  @impl Mix.Task
  def run(args) do
    cond do
      args == [] ->
        # Default to running directly without tmux
        Mix.shell().info("Starting GraphOS Protocol server directly...")
        run_implementation(args)
      args == ["start_and_join"] ->
        handle_start_and_join()
      args == ["direct"] ->
        Mix.shell().info("Starting GraphOS Protocol server directly...")
        run_implementation(args)
      true ->
        super(args)
    end
  end

  defp handle_start_and_join do
    Mix.shell().info("Starting Protocol server and joining the session...")

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
      Mix.shell().error("Failed to start Protocol server!")
      exit({:shutdown, 1})
    end
  end
end