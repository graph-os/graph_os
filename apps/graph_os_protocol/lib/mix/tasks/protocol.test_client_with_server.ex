defmodule Mix.Tasks.Protocol.TestClientWithServer do
  @moduledoc """
  Orchestrates running the TypeScript MCP client test against a temporarily started server.

  This task performs the following steps:
  1. Ensures the :mcp application is started.
  2. Starts the Bandit server with GraphOS.Protocol.Router on the configured test port.
  3. Waits briefly for the server to start.
  4. Runs the `mix protocol.test_client --port <port>` task.
  5. Stops the Bandit server.
  6. Exits with the status code from the `protocol.test_client` task.
  """
  alias IEx.App
  use Mix.Task
  require Logger

  @shortdoc "Starts server, runs TS client test, stops server."

  @application :graph_os_protocol
  @default_port 44444 # Default port for the server

  @impl Mix.Task
  def run(_args) do
    Mix.Project.get!()

    # Use a dedicated high port for this integration test
    port = @default_port

    # 1. Ensure :mcp is started
    Application.ensure_all_started(:mcp)

    # 2. Start the server
    Logger.info("Starting Bandit server for client test on dedicated port #{port}...")

    case Bandit.start_link(plug: GraphOS.Protocol.Router, port: port, startup_log: false) do
      {:ok, server_pid} ->
        try do
          # 3. Wait briefly
          Logger.info("Server started (PID: #{inspect(server_pid)}). Waiting briefly...")
          Process.sleep(500) # Increased sleep slightly

          # 4. Run the client test task, passing the port and ensuring test environment
          current_env = Mix.env() |> Atom.to_string()
          Logger.info("Running mix protocol.test_client --port #{port} in env #{current_env}...")
          # Use System.cmd to capture status and output. Run from project root (default).
          opts_run = [stderr_to_stdout: true]
          cmd_args = ["protocol.test_client", "--port", Integer.to_string(port)]
          # Explicitly set MIX_ENV for the sub-process if it's not the default dev
          if current_env != "dev" do
            opts_run = Keyword.put(opts_run, :env, %{"MIX_ENV" => current_env})
          end
          {output, status} = System.cmd("mix", cmd_args, opts_run)

          if status == 0 do
            Logger.info("protocol.test_client task completed successfully.")
            # Optionally log output even on success for debugging:
            # Logger.debug("Client test output:\n#{output}")
            status # Return 0 for success
          else
            # Raise an error including the output on failure
            Mix.raise("""
            protocol.test_client task failed with status #{status}. Output:
            --------------------------------------------------
            #{output}
            --------------------------------------------------
            """)
          end

        after
          # 5. Stop the Bandit server regardless of test outcome
          Logger.info("Stopping Bandit server (PID: #{inspect(server_pid)})...")
          if Process.alive?(server_pid) do
            Process.exit(server_pid, :normal)
            Process.sleep(100) # Brief pause for cleanup
          end
        end
        |> handle_exit_status() # Exit orchestrator task with the client test status

      {:error, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}} ->
        Mix.raise("Failed to start Bandit server: Port #{port} already in use.")

      {:error, reason} ->
        Mix.raise("Failed to start Bandit server: #{inspect(reason)}")
    end
  end

  # Helper to exit the Mix task with the correct status code
  defp handle_exit_status(0), do: :ok # Success
  defp handle_exit_status(status) when is_integer(status) and status > 0 do
    System.at_exit(fn _ -> exit({:shutdown, status}) end)
  end
end
