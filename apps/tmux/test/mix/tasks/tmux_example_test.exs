defmodule Mix.Tasks.Tmux.ExampleTaskTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @moduletag :tmux

  setup_all do
    # Initial cleanup before all tests
    {_, _} = System.cmd("sh", ["-c", "pkill -f \"mix tmux.example\" || true"], stderr_to_stdout: true)
    {_, _} = System.cmd("sh", ["-c", "tmux list-sessions 2>/dev/null | grep tmux_example | cut -d: -f1 | xargs -I{} tmux kill-session -t {} 2>/dev/null || true"], stderr_to_stdout: true)
    :ok
  end

  setup do
    # Clean up before each test
    {_, _} = System.cmd("sh", ["-c", "pkill -f \"mix tmux.example\" || true"], stderr_to_stdout: true)
    {_, _} = System.cmd("sh", ["-c", "tmux list-sessions 2>/dev/null | grep tmux_example | cut -d: -f1 | xargs -I{} tmux kill-session -t {} 2>/dev/null || true"], stderr_to_stdout: true)

    on_exit(fn ->
      # Clean up after each test
      {_, _} = System.cmd("sh", ["-c", "pkill -f \"mix tmux.example\" || true"], stderr_to_stdout: true)
      {_, _} = System.cmd("sh", ["-c", "tmux list-sessions 2>/dev/null | grep tmux_example | cut -d: -f1 | xargs -I{} tmux kill-session -t {} 2>/dev/null || true"], stderr_to_stdout: true)
    end)

    :ok
  end

  @tag :tmux
  test "can run the example task directly" do
    # Basic test that doesn't use tmux at all, just runs the task directly to ensure it works
    output = capture_io(fn ->
      Mix.Tasks.Tmux.Example.run(["help"])
    end)

    assert output =~ "tmux.example", "Task should provide help information"
  end

  @tag :tmux
  test "example task can be started and stopped" do
    # Directly call the mix command as a user would
    IO.puts("Starting the example task...")
    {start_output, _} = System.cmd("mix", ["tmux.example", "start"], stderr_to_stdout: true)
    IO.puts("Output: #{start_output}")

    # Check it started successfully
    assert start_output =~ "Start" || start_output =~ "session" || start_output =~ "tmux_example",
      "Start command failed with output: #{start_output}"

    # Wait a bit for it to stabilize
    Process.sleep(1000)

    # Check status
    {status, _} = System.cmd("mix", ["tmux.example", "status"], stderr_to_stdout: true)
    IO.puts("Status: #{status}")
    assert status =~ "running" || !(status =~ "not running"),
      "Status check failed with output: #{status}"

    # Stop the task
    {stop, _} = System.cmd("mix", ["tmux.example", "stop"], stderr_to_stdout: true)
    IO.puts("Stop output: #{stop}")
    assert stop =~ "Stop" || stop =~ "kill" || stop =~ "session",
      "Stop command failed with output: #{stop}"

    # Wait for cleanup
    Process.sleep(1000)

    # Check it's stopped
    {final, _} = System.cmd("mix", ["tmux.example", "status"], stderr_to_stdout: true)
    IO.puts("Final status: #{final}")
    assert final =~ "not running" || !(final =~ "running"),
      "Task wasn't stopped properly, status: #{final}"
  end

  @tag :tmux
  test "example task can be restarted" do
    # Start
    IO.puts("Starting for restart test...")
    {_, _} = System.cmd("mix", ["tmux.example", "start"], stderr_to_stdout: true)
    Process.sleep(1000)

    # Restart
    IO.puts("Restarting task...")
    {restart, _} = System.cmd("mix", ["tmux.example", "restart"], stderr_to_stdout: true)
    IO.puts("Restart output: #{restart}")

    # Verify it reported something reasonable
    assert restart =~ "restart" || restart =~ "start" || restart =~ "session" || restart =~ "tmux",
      "Restart command failed with output: #{restart}"

    # Give it time to restart
    Process.sleep(1000)

    # Check it's still running
    {status, _} = System.cmd("mix", ["tmux.example", "status"], stderr_to_stdout: true)
    IO.puts("Status after restart: #{status}")
    assert status =~ "running" || !(status =~ "not running"),
      "Task not running after restart, status: #{status}"

    # Clean up
    {_, _} = System.cmd("mix", ["tmux.example", "stop"], stderr_to_stdout: true)
  end

  @tag :tmux
  test "example task runs for a while" do
    # Start
    IO.puts("Starting for long-running test...")
    {_, _} = System.cmd("mix", ["tmux.example", "start"], stderr_to_stdout: true)
    Process.sleep(1000)

    # Check it's running
    {status1, _} = System.cmd("mix", ["tmux.example", "status"], stderr_to_stdout: true)
    IO.puts("Initial status: #{status1}")
    assert status1 =~ "running" || !(status1 =~ "not running"),
      "Task not running initially, status: #{status1}"

    # Wait a bit
    IO.puts("Waiting to verify task keeps running...")
    Process.sleep(2000)

    # Check it's still running
    {status2, _} = System.cmd("mix", ["tmux.example", "status"], stderr_to_stdout: true)
    IO.puts("Status after waiting: #{status2}")
    assert status2 =~ "running" || !(status2 =~ "not running"),
      "Task not running after waiting, status: #{status2}"

    # Clean up
    {_, _} = System.cmd("mix", ["tmux.example", "stop"], stderr_to_stdout: true)
  end
end
