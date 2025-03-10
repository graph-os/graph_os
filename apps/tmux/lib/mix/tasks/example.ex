defmodule Mix.Tasks.Tmux.Example do
  @moduledoc """
  An example task that demonstrates how to use the new TMUX.Task macro.

  This example shows how to create a task using the refactored TMUX.Task
  implementation rather than the older behavior-based approach.

  ## Usage

      mix tmux.example            # Check/start the task
      mix tmux.example start      # Start the task
      mix tmux.example stop       # Stop the task
      mix tmux.example restart    # Restart the task
      mix tmux.example join       # Join the task's tmux session
      mix tmux.example status     # Check the status of the task
      mix tmux.example help       # Display help information

  ## Environment Variables

  This example uses the following environment variables in the tmux session:

      EXAMPLE_MODE=development       # Sets the example mode
  """
  use TMUX.Task,
    key: "tmux_example",    # Custom session name
    cwd: "#{File.cwd!()}",      # Working directory for the session
    on_run: [:restart, :join],  # Actions to take when task is run with no args
    env: %{                     # Environment variables for the session
      "EXAMPLE_MODE" => "development"
    }

  @impl true
  def run(args) do
    # Call the parent implementation first, which will handle tmux operations
    super(args)
  end

  # Implementation for when the task runs directly (when tmux is not available)
  # This will be called by the parent implementation in the run/1 function
  defp run_implementation(_args) do
    IO.puts "Example task is running directly (without tmux)"
    IO.puts "This is executed when tmux is not available or not required"
    IO.puts "Current time: #{DateTime.utc_now()}"

    # Here you would include the same core functionality as your tmux session
    # would run, to ensure consistent behavior whether in tmux or not
    counter = 0

    # Print a counter every second, simulating a long-running task
    Stream.iterate(counter, &(&1 + 1))
    |> Enum.each(fn count ->
      IO.puts("Count: #{count}")
      :timer.sleep(1000)
    end)
  end
end
