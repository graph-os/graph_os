defmodule GraphOS.Core.FileWatcherTest do
  use ExUnit.Case, async: false
  @moduletag :code_graph

  alias GraphOS.Core.FileWatcher
  alias GraphOS.Core.CodeGraph
  # QueryAPI is used in some tests

  setup do
    # Initialize the graph store before each test
    :ok = CodeGraph.init()

    # Create a temporary directory for test files
    test_dir = Path.join(System.tmp_dir!(), "graphos_file_watcher_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(test_dir)

    # Clean up after the test
    on_exit(fn ->
      # Stop the file watcher if it's running
      try do
        FileWatcher.stop()
      catch
        :exit, _ -> :ok
      end

      # Clean up the test directory
      File.rm_rf!(test_dir)
    end)

    {:ok, %{test_dir: test_dir}}
  end

  describe "FileWatcher startup" do
    test "starts with default options", %{test_dir: test_dir} do
      # Start the watcher
      {:ok, _pid} = FileWatcher.start_link(test_dir)

      # Check the status
      status = FileWatcher.status()
      assert status.watching == [test_dir]
      assert is_integer(status.files_tracked)
    end

    test "starts with multiple directories", %{test_dir: test_dir} do
      # Create a second test directory
      test_dir2 = "#{test_dir}_2"
      File.mkdir_p!(test_dir2)
      on_exit(fn -> File.rm_rf!(test_dir2) end)

      # Start the watcher with both directories
      {:ok, _pid} = FileWatcher.start_link([test_dir, test_dir2])

      # Check the status
      status = FileWatcher.status()
      assert Enum.sort(status.watching) == Enum.sort([test_dir, test_dir2])
    end
  end

  describe "FileWatcher file detection" do
    test "detects new files", %{test_dir: test_dir} do
      # Start the watcher with a short poll interval for testing
      {:ok, _pid} = FileWatcher.start_link(test_dir, poll_interval: 100)

      # Get initial status
      initial_status = FileWatcher.status()
      initial_count = initial_status.files_tracked

      # Create a new file
      sample_module = """
      defmodule GraphOS.Test.FileWatcherTest.NewModule do
        def hello, do: :world
      end
      """

      file_path = Path.join(test_dir, "new_module.ex")
      File.write!(file_path, sample_module)

      # Wait for the file watcher to detect the change
      :timer.sleep(200)

      # Check if the file was detected
      updated_status = FileWatcher.status()
      assert updated_status.files_tracked > initial_count
      assert updated_status.last_update != nil
    end

    test "detects file changes", %{test_dir: test_dir} do
      # Create an initial file
      initial_module = """
      defmodule GraphOS.Test.FileWatcherTest.ModuleToChange do
        def initial, do: :initial
      end
      """

      file_path = Path.join(test_dir, "module_to_change.ex")
      File.write!(file_path, initial_module)

      # Start the watcher
      {:ok, _pid} = FileWatcher.start_link(test_dir, poll_interval: 100)

      # Wait for initial scan
      :timer.sleep(200)

      # Get the initial update time
      initial_status = FileWatcher.status()
      initial_update_time = initial_status.last_update
      IO.puts("Initial update time: #{inspect(initial_update_time)}")

      # Ensure some time passes for update detection
      # Increase sleep time to ensure file modification time changes
      :timer.sleep(1000)

      # Update the file
      updated_module = """
      defmodule GraphOS.Test.FileWatcherTest.ModuleToChange do
        def initial, do: :initial
        def added, do: :added
        def another, do: :another  # Add another function to ensure content is different
      end
      """

      File.write!(file_path, updated_module)

      # Get file modification time
      {:ok, %{mtime: mtime}} = File.stat(file_path, time: :posix)
      IO.puts("File modification time: #{inspect(mtime)}")

      # Wait for the file watcher to detect the change
      # Increase sleep time to ensure detection
      :timer.sleep(1000)

      # Check if the file change was detected
      updated_status = FileWatcher.status()
      IO.puts("Updated update time: #{inspect(updated_status.last_update)}")

      assert updated_status.last_update != initial_update_time
    end
  end

  describe "FileWatcher commands" do
    test "responds to rescan command", %{test_dir: test_dir} do
      # Start the watcher
      {:ok, _pid} = FileWatcher.start_link(test_dir, poll_interval: 1000)

      # Force a rescan
      :ok = FileWatcher.rescan()

      # Check if rescan updated the last_update time
      status = FileWatcher.status()
      assert status.last_update != nil
    end

    test "can be stopped", %{test_dir: test_dir} do
      # Start the watcher
      {:ok, pid} = FileWatcher.start_link(test_dir)

      # Stop the watcher
      :ok = FileWatcher.stop()

      # Check if the process is down
      refute Process.alive?(pid)
    end
  end
end
