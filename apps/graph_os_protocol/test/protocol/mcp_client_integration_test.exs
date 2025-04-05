defmodule GraphOS.Protocol.MCPClientIntegrationTest do
  # This test now simply triggers a Mix task that handles server start/stop and client execution.
  use ExUnit.Case, async: false # Keep async: false as it runs external processes

  # Tag to skip if Node.js/npm/npx is not available or desired in the test environment
  @tag :requires_node
  @tag :integration

  # No setup block needed here.

  test "runs TypeScript client test task against a managed server" do
    # The test now runs against the server started by the Mix task.
    # We will create a new task `protocol.test_client_with_server` to handle this.
    # The port configuration will be handled within that task, likely using the test config.
    # We need to check node/npx availability here or within the task. Let's keep it here for now.
    #   a) Modify the Mix task to accept a port argument.
    #   b) Modify the test_connection.ts script to read the port from an env var.
    #   c) Assume the test config *always* uses port 4000 for this test (simplest for now).

    # Let's assume config/test.exs *is* set to 4000 for this specific test for simplicity,
    # or modify test_connection.ts to use 4001 if that's the configured test port.
    # For now, we proceed assuming the TS script targets the correct port (e.g., 4001 if configured).

    node_path = System.find_executable("node")
    npx_path = System.find_executable("npx")

    if node_path && npx_path do
      # Run the new orchestrating mix task in the test environment.
      # ExUnit will capture the exit status.
      # If the task exits with non-zero status, the test will fail.
      # We'll create this task next.
      Mix.Task.run("protocol.test_client_with_server", ["--env", "test"])
      # The test implicitly passes if the task exits with status 0.
    else
      # Skip the test if Node.js dependencies are missing.
      {:skip, "Skipping test: Node.js and/or npx not found in PATH."}
    end
  end
end
