defmodule Mix.Tasks.Protocol.TestClient do
  @moduledoc """
  Runs the TypeScript MCP client test script against a running server.

  This task assumes the MCP server (e.g., started via `mix protocol.server start`
  or within an ExUnit test setup) is running on the expected port (default localhost:4000).

  It performs the following steps:
  1. Checks for `node` and `npx` executables.
  2. Runs `npm install` in the `mcp_client_test` directory.
  3. Runs the `test_connection.ts` script using `npx tsx`.
  4. Streams the output and exits with the script's status code.
  """
  use Mix.Task
  require Logger

  @shortdoc "Runs the TypeScript MCP client test script"

  @switches [port: :integer]
  @aliases [p: :port]

  @impl Mix.Task
  def run(args) do
    # Parse command-line options
    {opts, _parsed_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)
    port = Keyword.get(opts, :port, 4000) # Default to 4000 if --port is not given

    # Ensure Mix project is loaded (needed for Path.expand/2 relative to root)
    Mix.Project.get!()

    # 1. Check dependencies
    node_path = System.find_executable("node")
    npx_path = System.find_executable("npx")

    unless node_path && npx_path do # Check if both paths are non-nil
      Mix.raise("""
      Node.js and npx are required to run the TypeScript client test.
      Please ensure they are installed and available in your PATH.
      """)
    end

    # 2. Define paths relative to the project root
    app_cwd = File.cwd!() # CWD when this task is invoked via System.cmd might be the app dir
    project_root = Path.expand("../../", app_cwd) # Go up TWO levels to get umbrella root
    client_test_dir = Path.join(project_root, "mcp_client_test") # Path to the TS test dir from umbrella root
    ts_test_script = "test_connection.ts" # Relative to client_test_dir
    ts_script_full_path = Path.join(client_test_dir, ts_test_script)

    Mix.shell().info("protocol.test_client CWD (app dir): #{app_cwd}") # Debug info
    Mix.shell().info("protocol.test_client calculated project root: #{project_root}") # Debug info
    Mix.shell().info("protocol.test_client looking for script at: #{ts_script_full_path}") # Debug info

    # Mix.shell().info("Project root determined as: #{project_root}") # Debugging info
    # Mix.shell().info("Looking for TS script at: #{ts_script_full_path}") # Debugging info

    unless File.exists?(ts_script_full_path) do
      Mix.raise("TypeScript test script not found at #{ts_script_full_path}")
    end

    # 3. Run npm install
    Mix.shell().info("Running npm install in #{client_test_dir}...")
    opts_install = [stderr_to_stdout: true, cd: client_test_dir]
    case System.cmd("npm", ["install"], opts_install) do
      {output, 0} ->
        Mix.shell().info("npm install completed.")
        # Log output only if needed for debugging, can be verbose
        # Logger.debug("npm install output:\n#{output}")
      {output, status} ->
        Mix.raise("""
        npm install failed with status #{status}. Output:
        #{output}
        """)
    end

    # 4. Run the TypeScript test script
    Mix.shell().info("Running TypeScript client test: #{ts_test_script} against port #{port}...")
    # Set environment variable for the script
    env = %{"MCP_SERVER_PORT" => Integer.to_string(port)}
    opts_run = [stderr_to_stdout: true, cd: client_test_dir, into: IO.stream(:stdio, :line), env: env]
    # Use into: IO.stream to get live output
    case System.cmd("npx", ["tsx", ts_test_script], opts_run) do
      {_output, 0} ->
        Mix.shell().info("TypeScript client test completed successfully.")
        # Exit with status 0 handled implicitly by Mix.Task
      {_output, status} ->
        # Don't raise here, let the test runner handle the failure status
        Mix.shell().error("TypeScript client test failed with status #{status}.")
        # Exit the Mix task with the non-zero status code
        System.at_exit(fn _ -> exit({:shutdown, status}) end)
    end
  end
end
