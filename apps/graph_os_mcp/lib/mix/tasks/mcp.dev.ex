defmodule Mix.Tasks.Mcp.Dev do
  @moduledoc """
  Start a development server for GraphOS with code reloading.

  This task starts a development server with:
  - MCP endpoint to CodeGraph
  - Code reloading (similar to Phoenix dev server)
  - An endpoint for showing graph content of the current file or module

  ## Usage

      mix mcp.dev

  ## Options

      --port, -p    The port to start the development server on (default: 4000)
      --host, -h    The host to bind the development server to (default: 127.0.0.1)
      --no-halt     Do not halt the system after starting the server
  """

  use Mix.Task
  require Logger

  @shortdoc "Start a development server for GraphOS"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [port: :integer, host: :string, no_halt: :boolean],
      aliases: [p: :port, h: :host]
    )

    # Get options with defaults
    port = Keyword.get(opts, :port, 4000)
    host_str = Keyword.get(opts, :host, "127.0.0.1")
    no_halt = Keyword.get(opts, :no_halt, false)

    # Parse host
    host = parse_host(host_str)

    # Apply dev configuration
    Application.put_env(:graph_os_mcp, :http_port, port)
    Application.put_env(:graph_os_mcp, :http_host, host)
    Application.put_env(:graph_os_mcp, :http_base_path, "")
    Application.put_env(:graph_os_mcp, :dev_mode, true)

    # Temporarily disable file watcher
    # {:ok, _pid} = start_file_watcher()

    # Start the application
    Mix.Task.run("app.start")

    # Print start message
    Mix.shell().info([
      IO.ANSI.green(), "GraphOS Development Server running at http://#{host_str}:#{port}", IO.ANSI.reset(),
      "\n",
      "MCP endpoint: ", IO.ANSI.cyan(), "http://#{host_str}:#{port}/mcp", IO.ANSI.reset(),
      "\n",
      "Graph view: ", IO.ANSI.cyan(), "http://#{host_str}:#{port}/graph", IO.ANSI.reset(),
      "\n\n",
      IO.ANSI.yellow(), "Use Ctrl+C to stop", IO.ANSI.reset()
    ])

    # Keep the task running unless --no-halt was given
    unless no_halt do
      :timer.sleep(:infinity)
    end
  end

  # Parse host string into tuple or binary
  defp parse_host("0.0.0.0"), do: {0, 0, 0, 0}
  defp parse_host("127.0.0.1"), do: {127, 0, 0, 1}
  defp parse_host(host) do
    case host |> String.split(".") |> Enum.count() do
      4 ->
        host
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)
        |> List.to_tuple()
      _ ->
        host
    end
  end

  # File watching functionality is temporarily disabled
  # We'll implement a proper file watching mechanism later
  #
  # # Start file watcher for code reloading
  # defp start_file_watcher do
  #   apps_dir = Path.join(Mix.Project.deps_path() |> Path.dirname(), "apps")
  #
  #   # Start a process that watches for file changes
  #   pid = spawn_link(fn ->
  #     # Start the file system monitor
  #     {:ok, _watcher_pid} = FileSystem.start_link(dirs: [apps_dir])
  #
  #     # Subscribe to file system events
  #     FileSystem.subscribe(FileSystem)
  #
  #     # Run the watcher loop
  #     watcher_loop()
  #   end)
  #
  #   {:ok, pid}
  # end
  #
  # # File watcher loop
  # defp watcher_loop do
  #   receive do
  #     {:file_event, _watcher_pid, {path, events}} ->
  #       # Handle file events
  #       if code_reload_needed?(path, events) do
  #         reload_code(path)
  #       end
  #       watcher_loop()
  #     {:file_error, _watcher_pid, error} ->
  #       Logger.error("File watcher error: #{inspect(error)}")
  #       watcher_loop()
  #   end
  # end
  #
  # # Determine if code reload is needed based on file path and events
  # defp code_reload_needed?(path, events) do
  #   # Only reload .ex and .exs files that have been modified
  #   Path.extname(path) in [".ex", ".exs"] and :modified in events
  # end
  #
  # # Reload code for the given path
  # defp reload_code(path) do
  #   try do
  #     # Get relative path for display
  #     apps_dir = Path.join(Mix.Project.deps_path() |> Path.dirname(), "apps")
  #     rel_path = Path.relative_to(path, apps_dir)
  #
  #     # Attempt to reload the file
  #     Code.compile_file(path)
  #
  #     Logger.info("Recompiled #{rel_path}")
  #
  #     # Broadcast file change event for dev server clients
  #     file_info = %{
  #       path: rel_path,
  #       timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  #     }
  #
  #     # Use the MCP broadcast mechanism to notify clients
  #     GraphOS.MCP.Service.EventBroadcaster.broadcast("dev", "file_changed", file_info)
  #   rescue
  #     e ->
  #       Logger.error("Failed to reload #{path}: #{Exception.message(e)}")
  #   end
  # end
end
