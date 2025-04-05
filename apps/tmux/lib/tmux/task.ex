defmodule TMUX.Task do
  @moduledoc """
  A macro for creating tmux-aware mix tasks.

  This module provides a simple way to create mix tasks that automatically
  use tmux sessions. It supports operations like starting, stopping, joining,
  and restarting long-running processes in dedicated tmux sessions.

  ## Usage

  To create a tmux-aware mix task, use this module in your task module:

  ```elixir
  defmodule Mix.Tasks.YourApp.YourTask do
    use TMUX.Task,
      key: "your_app_task",       # The name to use for the tmux session
      cwd: "path/to/dir",         # Working directory for the session
      on_run: [:restart, :join]   # Actions to take when task is run

    # Implement the run/1 function as normal
    def run(_) do
      # Call the parent implementation to handle tmux operations
      super(_)

      # Your long-running process implementation here
      Process.sleep(:infinity)
    end
  end
  ```

  This automatically handles finding or creating tmux sessions and provides
  standard commands like `start`, `stop`, `restart`, `status`, and `join`.

  ## Options

  * `:key` - A unique key for the tmux session (defaults to task name)
  * `:cwd` - Working directory for the session (defaults to current directory)
  * `:on_run` - List of actions to take when run with no args (e.g., [:restart, :join])
  * `:env` - Environment variables to set in the tmux session
  * `:tmux_required` - Whether to error if tmux is not available (default: false)
  * `:auto_join` - Whether to automatically join the session (default: true)
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use Mix.Task

      @session_key unquote(Keyword.get(opts, :key, nil))
      @working_dir unquote(Keyword.get(opts, :cwd, "#{File.cwd!()}"))
      @on_run unquote(Keyword.get(opts, :on_run, []))
      @env unquote(Keyword.get(opts, :env, %{}))
      @tmux_required unquote(Keyword.get(opts, :tmux_required, false))
      @auto_join unquote(Keyword.get(opts, :auto_join, true))

      # Generate default session name from the module name if none provided
      @session_name @session_key ||
                   __MODULE__
                   |> Atom.to_string()
                   |> String.replace_prefix("Elixir.Mix.Tasks.", "")
                   |> String.replace(".", "_")
                   |> String.downcase()

      # Generate task name for display purposes
      @task_name __MODULE__
                 |> Atom.to_string()
                 |> String.replace_prefix("Elixir.Mix.Tasks.", "")
                 |> String.downcase()

      # Store the module name for execution within tmux
      @module_name __MODULE__

      @impl Mix.Task
      def run(args) do
        # Default tmux management commands
        commands = %{
          "start" => &handle_start/0,
          "stop" => &handle_stop/0,
          "restart" => &handle_restart/0,
          "join" => &handle_join/0,
          "status" => &handle_status/0,
          "help" => &handle_help/0,
          "logs" => &handle_logs/0
        }

        # Check if tmux is available
        if !TMUX.available?() do
          if @tmux_required do
            Mix.raise """
            TMUX is required for this task but is not available on your system.
            Please install tmux and try again.
              On macOS: brew install tmux
              On Ubuntu/Debian: sudo apt install tmux
              On Fedora/RHEL: sudo dnf install tmux
            """
          else
            print_warning("TMUX not available. Running task directly without session management.")

            # Determine if we should run the implementation based on the args and on_run
            should_run_implementation =
              if args == [] do
                # No args provided, check on_run settings
                if !Enum.empty?(@on_run) do
                  # Only run if on_run contains start or restart
                  Enum.any?(@on_run, &(&1 in [:start, :restart]))
                else
                  # Default behavior: run implementation with no args
                  true
                end
              else
                # With args, only run for start command
                List.first(args) == "start"
              end

            if should_run_implementation do
              # Run standard implementation if tmux isn't available but we need to execute
              run_implementation(args)
            end
          end
        # Otherwise, handle tmux operations
        else
          if args == [] do
            # Process on_run options if no args provided
            on_run_actions = @on_run |> Enum.map(&Atom.to_string/1)

            if Enum.empty?(on_run_actions) do
              # Default behavior: check if session exists, join if it does, start if it doesn't
              if TMUX.session_exists?(@session_name) do
                print_success("Session #{@session_name} exists.")
                print_info("Join with: mix #{@task_name} join")
              else
                handle_start()
              end
            else
              # Execute the configured actions
              Enum.each(on_run_actions, fn action ->
                case action do
                  "start" -> handle_start()
                  "stop" -> handle_stop()
                  "restart" -> handle_restart()
                  "join" -> handle_join()
                  "status" -> handle_status()
                  "logs" -> handle_logs()
                  _ -> print_warning("Unknown action: #{action}")
                end
              end)
            end
          else
            # Execute commands based on args
            execute_command(commands, List.first(args), args, @task_name)
          end
        end
      end

      # Run the actual implementation (for use when not redirecting to tmux)
      defp run_implementation(args) do
        # Override with your own implementation in the task
      end

      # Standard command handlers
      defp handle_start do
        if !TMUX.session_exists?(@session_name) do
          # Create a new tmux session
          print_info("Starting task in tmux session: #{@session_name}...")
          # Use direct command for more reliability
          {result, status} = System.cmd("tmux", ["new-session", "-d", "-s", @session_name, "-c", @working_dir], stderr_to_stdout: true)

          if status != 0 do
            print_error("Failed to create session: #{result}")
            :error
          else
            # Prepare environment variables
            env_map = Map.merge(%{"MIX_ENV" => "#{Mix.env()}"}, @env)

            # Set environment variables in the session
            Enum.each(env_map, fn {key, value} ->
              System.cmd("tmux", ["send-keys", "-t", @session_name, "export #{key}=#{value}", "Enter"])
            end)

            # Send commands to run the task in the tmux session
            module_str = @module_name |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
            run_cmd = "cd #{@working_dir} && mix run -e '#{module_str}.run([])'"
            System.cmd("tmux", ["send-keys", "-t", @session_name, run_cmd, "Enter"])

            print_success("Started session #{@session_name}.")
            if @auto_join do
              # Wait a moment for the session to be fully started
              :timer.sleep(500)
              handle_auto_join()
            else
              print_info("Join with: mix #{@task_name} join")
            end
            :ok
          end
        else
          print_success("Session #{@session_name} already exists.")
          if @auto_join do
            handle_auto_join()
          else
            print_info("Join with: mix #{@task_name} join")
          end
          :ok
        end
      end


      defp handle_logs(lines \\ 50) do
        # Get the last `lines` lines from the tmux session
        {output, _} = System.cmd("tmux", ["capture-pane", "-pt", @session_name, "-S", "-#{lines}"], stderr_to_stdout: true)
        if output && output != "" do
          print_info("\nSession logs (last #{lines} lines):")
          output
          |> String.split("\n")
          |> Enum.filter(fn line -> String.trim(line) != "" end)
          |> Enum.each(fn line -> print_info("  " <> line) end)
        else
          print_warning("No logs available or session not running.")
        end
      end

      # Handle automatic joining of tmux sessions
      defp handle_auto_join do
        shell_command = "tmux attach-session -t #{@session_name}"
        print_info("Attempting to join the session...")

        # Check if we're in a truly interactive terminal
        is_interactive = System.get_env("TERM") != nil && IO.ANSI.enabled?() && tty_available?()

        # For debug purposes, print more detailed information
        term_env = System.get_env("TERM")
        ansi_enabled = IO.ANSI.enabled?()
        tty_check = tty_available?()

        if is_interactive do
          print_info("To detach from the session once attached, press Ctrl+B then D")
          print_info("Joining now...")

          # Try both joining methods, starting with the more reliable one
          try_join_with_exec = fn ->
            # Try to use posix exec to replace the current process with tmux
            # This is the most reliable method on most systems
            System.cmd("exec", ["tmux", "attach-session", "-t", @session_name], into: IO.stream(:stdio, :line))
          end

          try_join_with_sh = fn ->
            # Fallback to sh -c approach
            System.cmd("sh", ["-c", shell_command], into: IO.stream(:stdio, :line))
          end

          try do
            # Try the exec method first
            try_join_with_exec.()
          rescue
            _ ->
              # If that fails, try the sh method
              try do
                try_join_with_sh.()
              rescue
                _ ->
                  # Last resort - try using OS.cmd directly if this is likely an IDE terminal
                  # This works better in some IDE environments like VS Code or Cursor
                  ide_terminal = System.get_env("TERM_PROGRAM") != nil ||
                                 (System.get_env("TERM") || "") =~ "xterm" ||
                                 (System.get_env("EDITOR") || "") =~ "code"

                  if ide_terminal do
                    print_info("Trying IDE-compatible join method...")
                    try do
                      if :os.type() == {:unix, :darwin} do
                        # Use open terminal command on macOS
                        System.cmd("open", ["-a", "Terminal", shell_command])
                      else
                        # Use gnome-terminal on Linux if available
                        System.cmd("gnome-terminal", ["--", "bash", "-c", "#{shell_command}; exec bash"], stderr_to_stdout: true)
                      end
                    rescue
                      _ ->
                        print_warning("Failed to join session automatically.")
                        print_manual_join_instructions(shell_command)
                    end
                  else
                    print_warning("Failed to join session automatically.")
                    print_manual_join_instructions(shell_command)
                  end
              end
          end
        else
          # Provide more detailed diagnostic info
          diagnostic_info = """
          Can't auto-join (not in an interactive terminal).
          Terminal detection details:
            - TERM environment: #{if term_env, do: term_env, else: "not set"}
            - ANSI enabled: #{ansi_enabled}
            - TTY available: #{tty_check}
          """
          print_info(diagnostic_info)
          print_manual_join_instructions(shell_command)
        end
      end

      # Show instructions for manually joining the session
      defp print_manual_join_instructions(shell_command) do
        print_info("To manually join the session, run this command in your terminal:")
        print_info(IO.ANSI.format([:cyan, "  #{shell_command}"]))
        print_info("To detach from the session once attached, press Ctrl+B then D")

        # Try to show pane contents as a preview
        try do
          {output, 0} = System.cmd("tmux", ["capture-pane", "-pt", @session_name, "-S", "-5"], stderr_to_stdout: true)
          if output && output != "" do
            print_info("\nSession preview (last few lines):")
            output
            |> String.split("\n")
            |> Enum.filter(fn line -> String.trim(line) != "" end)
            |> Enum.take(-5)
            |> Enum.each(fn line -> print_info("  " <> line) end)
          end
        rescue
          _ -> :ok
        end
      end

      # Helper to check if we're in a true TTY
      defp tty_available? do
        try do
          case System.cmd("test", ["-t", "0"], stderr_to_stdout: true) do
            {_, 0} -> true
            _ -> false
          end
        rescue
          _ -> false
        end
      end

      defp handle_stop do
        if TMUX.session_exists?(@session_name) do
          print_info("Stopping tmux session: #{@session_name}...")
          :ok = TMUX.stop_session(@session_name)
          print_success("Stopped session #{@session_name}")
        else
          # Still mention stopping/killing in the output for test compatibility
          print_error("Cannot stop session #{@session_name} - not running")
        end
      end

      defp handle_restart do
        # First try to stop the session if it exists
        if TMUX.session_exists?(@session_name) do
          print_info("Stopping tmux session: #{@session_name}...")
          # Use direct command for more reliability
          System.cmd("tmux", ["kill-session", "-t", @session_name], stderr_to_stdout: true)
          :timer.sleep(1000)
        end

        # Ensure it's really gone before starting a new one
        if TMUX.session_exists?(@session_name) do
          print_error("Failed to stop session #{@session_name}, forcing kill...")
          System.cmd("tmux", ["kill-session", "-t", @session_name], stderr_to_stdout: true)
          :timer.sleep(500)
        end

        # Start a new session
        print_info("Starting task in tmux session: #{@session_name}...")
        # Use direct command for more reliability
        {result, status} = System.cmd("tmux", ["new-session", "-d", "-s", @session_name, "-c", @working_dir], stderr_to_stdout: true)

        if status != 0 do
          print_error("Failed to create session: #{result}")
          :error
        else
          # Prepare environment variables
          env_map = Map.merge(%{"MIX_ENV" => "#{Mix.env()}"}, @env)

          # Set environment variables in the session
          Enum.each(env_map, fn {key, value} ->
            System.cmd("tmux", ["send-keys", "-t", @session_name, "export #{key}=#{value}", "Enter"])
          end)

          # Send commands to run the task in the tmux session
          module_str = @module_name |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
          run_cmd = "cd #{@working_dir} && mix run -e '#{module_str}.run([])'"
          System.cmd("tmux", ["send-keys", "-t", @session_name, run_cmd, "Enter"])

          print_success("Restarted session #{@session_name}.")
          print_info("Join with: mix #{@task_name} join")
          :ok
        end
      end

      defp handle_join do
        # Use a robust session existence check with retries
        if TMUX.session_exists?(@session_name, 2) do
          print_info("Joining tmux session: #{@session_name}...")
          print_info("Note: To detach from the session, press Ctrl+B then D")

          # Use a simple direct approach to joining the session
          # This avoids the complexities of multiple join strategies
          case System.cmd("tmux", ["attach-session", "-t", @session_name], into: IO.stream(:stdio, :line)) do
            {_, 0} ->
              # Successfully joined and detached
              :ok

            {_, _} ->
              # If joining fails, provide manual instructions
              print_warning("Failed to join session interactively.")
              print_info("To join manually, run in your terminal: tmux attach-session -t #{@session_name}")
              show_session_preview(@session_name)
          end
        else
          print_error("Session #{@session_name} is not running")
          print_info("Start with: mix #{@task_name} start")
        end
      end

      # Show a preview of the session content
      defp show_session_preview(session_name) do
        try do
          # Show a brief status of the session
          {output, _} = System.cmd("tmux", ["capture-pane", "-pt", session_name], stderr_to_stdout: true)
          IO.puts "\nSession output preview:"

          # Try to get the last few lines of output
          last_lines = output
                      |> String.split("\n")
                      |> Enum.reject(fn line -> line == "" end)
                      |> Enum.take(-10)
                      |> Enum.join("\n")

          IO.puts(last_lines)
        rescue
          _ -> print_warning("Could not capture session output")
        end
      end

      defp handle_status do
        if TMUX.session_exists?(@session_name) do
          print_success("Session #{@session_name} is running")
          print_info("Join with: mix #{@task_name} join")
        else
          print_error("Session #{@session_name} is not running")
          print_info("Start with: mix #{@task_name} start")
        end
      end

      defp handle_help do
        commands = [
          "start   - Start the task in a tmux session",
          "stop    - Stop the running task",
          "restart - Restart the task",
          "join    - Join the tmux session",
          "status  - Check the status of the task",
          "help    - Display this help message"
        ]

        IO.puts "\nAvailable commands for #{@task_name}:"
        Enum.each(commands, &IO.puts("  #{&1}"))
        IO.puts ""

        # Print current status
        handle_status()
      end

      # Helper to handle command execution
      defp execute_command(commands, command, args, task_name) do
        cond do
          command == nil ->
            handle_help()

          Map.has_key?(commands, command) ->
            action = Map.get(commands, command)
            action.()

          true ->
            print_error("Unknown command: #{command}")
            print_info("Run 'mix #{task_name} help' for usage information")
        end
      end

      # Helper to format output with colors
      defp print_success(message), do: IO.puts(IO.ANSI.format([:green, "✓ ", message]))
      defp print_error(message), do: IO.puts(IO.ANSI.format([:red, "✗ ", message]))
      defp print_warning(message), do: IO.puts(IO.ANSI.format([:yellow, "! ", message]))
      defp print_info(message), do: IO.puts(message)

      # Allow overriding run_implementation
      defoverridable [run: 1, run_implementation: 1]
    end
  end
end
