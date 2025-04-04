# TMUX

This component provides tmux session management utilities for the GraphOS umbrella project. It enables other applications to run long-running processes in tmux sessions for better development and debugging experience.

## Features

- Seamless tmux session management in mix tasks
- Macro for creating tmux-aware mix tasks
- Support for standard commands (start, stop, restart, join, status)
- Automatic session creation and management
- Fallback to direct execution when tmux is not available

## Usage

### In Other Applications

To use tmux functionality in other GraphOS applications:

1. Add the dependency to your mix.exs file:

```elixir
def deps do
  [
    {:tmux, in_umbrella: true}
  ]
end
```

2. Create a tmux-aware mix task using the TMUX.Task macro:

```elixir
defmodule Mix.Tasks.YourApp.YourTask do
  use TMUX.Task,
    key: "your_app_task",       # The name to use for the tmux session
    cwd: "/path/to/working/dir", # Working directory for the session
    on_run: [:restart, :join]   # Actions to take when task is run with no args
    
  @impl true
  def run(args) do
    # Call the parent implementation first, which will handle tmux operations
    super(args)
    
    # Your long-running process implementation
    IO.puts "Task is running in TMUX session"
    Process.sleep(:infinity)
  end
end
```

## Example Task

The component includes an example task that demonstrates how to use the TMUX.Task macro:

```bash
# Check if the task is running or start it
mix tmux.example

# Start the example task
mix tmux.example start

# Check status
mix tmux.example status

# Join the session
mix tmux.example join

# Restart the task
mix tmux.example restart

# Stop the task
mix tmux.example stop
```

## Architecture

### Components

- **TMUX**: Core utility module for interacting with tmux
- **TMUX.Task**: Macro for creating tmux-aware mix tasks
- **Mix.TMUXRunner**: Low-level utilities for running tasks in tmux sessions

### Workflow

1. Tasks using `TMUX.Task` are automatically set up with tmux session management
2. When such a task is run with the "start" command, it creates a tmux session
3. The task's implementation runs within the tmux session
4. Users can detach from the session (Ctrl+B, D) while the process continues running
5. The task can be managed with "status", "join", and "stop" commands
6. The `on_run` option can specify default actions when the task is run without arguments

## Requirements

- TMUX must be installed on the system for the session management features to work
- If tmux is not available, tasks will fall back to running directly

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tmux>.

