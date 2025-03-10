defmodule GraphOS.DevWeb.CodeGraphControllerTest do
  @moduledoc false
  use GraphOS.DevWeb.ConnCase

  alias GraphOS.Core.CodeGraph
  alias GraphOS.Core.CodeGraph.Service, as: CodeGraphService

  setup do
    # Get the path to the current file and use it to determine the app path
    test_file_path = __ENV__.file
    app_dir = Path.join(Path.dirname(test_file_path), "../../../")
    dev_file_path = Path.join(app_dir, "lib/graph_os/dev.ex")

    # Normalize paths
    app_dir = Path.expand(app_dir)
    dev_file_path = Path.expand(dev_file_path)

    # Create file relative path that will work with the controllers
    file_rel_path = "lib/graph_os/dev.ex"

    # Confirm the file exists
    if !File.exists?(dev_file_path) do
      flunk("Test file not found: #{dev_file_path}")
    end

    # Stop the existing CodeGraphService if it's running
    service_pid = Process.whereis(CodeGraphService)
    if service_pid do
      ref = Process.monitor(service_pid)
      Process.exit(service_pid, :kill)
      receive do
        {:DOWN, ^ref, :process, _pid, _reason} -> :ok
      after
        1000 -> :ok
      end
    end

    # Wait a moment for cleanup
    Process.sleep(100)

    # Start the CodeGraph Service with app directory to watch
    {:ok, _pid} = CodeGraphService.start_link([
      watched_dirs: [app_dir],
      file_pattern: "**/*.ex",
      auto_reload: false
    ])

    # Wait a moment for service to initialize
    Process.sleep(200)

    # Initialize the code graph
    :ok = CodeGraph.init()

    # Build the graph with the app's directory
    {:ok, stats} = CodeGraph.build_graph(app_dir)
    IO.puts("Graph built with stats: #{inspect(stats)}")

    # Wait longer for the graph to be fully built and indexed
    Process.sleep(500)

    # Cleanup after tests
    on_exit(fn ->
      service_pid = Process.whereis(CodeGraphService)
      if service_pid do
        ref = Process.monitor(service_pid)
        Process.exit(service_pid, :kill)
        receive do
          {:DOWN, ^ref, :process, _pid, _reason} -> :ok
        after
          1000 -> :ok
        end
      end
    end)

    # Share the file path in the test context for test use
    {:ok, %{
      app_dir: app_dir,
      dev_file_path: dev_file_path,
      file_rel_path: file_rel_path,
      module_name: "GraphOS.Dev"
    }}
  end

  describe "API routes" do
    test "GET /api/code-graph/list", %{conn: conn} do
      conn = get(conn, ~p"/api/code-graph/list")
      assert json_response(conn, 200)
    end

    test "GET /api/code-graph/module", %{conn: conn, module_name: module_name} do
      conn = get(conn, ~p"/api/code-graph/module?name=#{module_name}")
      assert json_response(conn, 200)
    end

    test "GET /api/code-graph/file", %{conn: conn, file_rel_path: file_path} do
      conn = get(conn, ~p"/api/code-graph/file?path=#{file_path}")
      assert conn.status in [200, 400, 404]
    end
  end
end
