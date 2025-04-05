defmodule GraphOS.Protocol.Test.McpServerCase do
  @moduledoc """
  A CaseTemplate for tests requiring a running MCP/Bandit server.

  This module handles starting the necessary applications and the Bandit
  server with the GraphOS.Protocol.Router plug on a configured test port.
  It ensures the server is shut down cleanly after each test using `on_exit`.

  Tests using this case should `use GraphOS.Protocol.Test.McpServerCase`
  and will receive `%{port: port, server_pid: pid}` in their context.
  """
  use ExUnit.CaseTemplate
  require Logger

  using do
    quote do
      # Import Plug.Test helpers if needed by tests using this case
      import Plug.Test
      import Plug.Conn
      require Logger # Add require Logger inside the quote block

      # Setup block to start the server for each test
      setup tags do
        # Skip tests tagged with :requires_node if node/npx aren't found
        if tags[:requires_node] && !(System.find_executable("node") && System.find_executable("npx")) do
          {:skip, "Skipping test: Node.js and/or npx not found in PATH."}
        else
          # Ensure :mcp is started (for registry, supervisor)
          Application.ensure_all_started(:mcp)

          # Get configured test port (e.g., 4001 from config/test.exs)
          # Allow overriding via tags map for specific tests if needed in the future
          default_port = Application.get_env(:bandit, :port, 4001)
          port = Map.get(tags, :port, default_port) # Use Map.get on the tags map

          Logger.info("Starting Bandit server for test on port #{port}")

          # Start Bandit directly with the Router plug
          case Bandit.start_link(plug: GraphOS.Protocol.Router, port: port, startup_log: false) do
            {:ok, server_pid} ->
              # Ensure server is stopped when test finishes
              on_exit(fn ->
                if Process.alive?(server_pid) do
                  Logger.info("Stopping Bandit server (PID: #{inspect(server_pid)}) for test cleanup")
                  Process.exit(server_pid, :normal)
                  Process.sleep(100) # Brief pause for cleanup
                end
              end)

              # Brief pause to ensure server is ready
              Process.sleep(100)

              # Pass port and pid to the test context
              {:ok, %{port: port, server_pid: server_pid}}

            {:error, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}} ->
              # Explicitly handle port conflict error
              {:skip, "Skipping test: Port #{port} already in use."}

            {:error, reason} ->
              # Fail setup for other Bandit start errors
              {:error, "Failed to start Bandit server: #{inspect(reason)}"}
          end
        end
      end
    end
  end
end
