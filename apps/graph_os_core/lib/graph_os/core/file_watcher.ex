defmodule GraphOS.Core.FileWatcher do
  @moduledoc """
  Watches files for changes and updates the code graph in real-time.

  This module provides functionality to:
  - Monitor directories for file changes
  - Update the code graph when files are created, modified, or deleted
  - Support automatic code reloading in development environments
  """

  use GenServer
  require Logger

  alias GraphOS.Core.CodeGraph

  # 1 second polling interval
  @poll_interval 1000

  # Public API

  @doc """
  Start a file watcher process.

  ## Parameters

  - `directory` - The directory to watch
  - `opts` - Options for the watcher

  ## Options

  - `:recursive` - Whether to watch subdirectories (default: true)
  - `:file_pattern` - Pattern for files to watch (default: "**/*.ex")
  - `:exclude_pattern` - Pattern for files to exclude (optional)
  - `:auto_reload` - Whether to reload modules on change (default: false)
  - `:poll_interval` - Interval between file checks in ms (default: 1000)

  ## Examples

      iex> {:ok, pid} = GraphOS.Core.FileWatcher.start_link(["lib"])
      {:ok, #PID<0.123.0>}

  """
  @spec start_link(Path.t() | [Path.t()], keyword()) :: GenServer.on_start()
  def start_link(directory, opts \\ []) when is_binary(directory) or is_list(directory) do
    GenServer.start_link(__MODULE__, {directory, opts}, name: __MODULE__)
  end

  @doc """
  Stop the file watcher.

  ## Examples

      iex> GraphOS.Core.FileWatcher.stop()
      :ok

  """
  @spec stop() :: :ok
  def stop do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  Get the current status of the file watcher.

  ## Examples

      iex> GraphOS.Core.FileWatcher.status()
      %{watching: ["lib"], files_tracked: 42, last_update: ~U[2023-04-01 12:34:56Z]}

  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Force a rescan of watched directories.

  ## Examples

      iex> GraphOS.Core.FileWatcher.rescan()
      :ok

  """
  @spec rescan() :: :ok
  def rescan do
    GenServer.cast(__MODULE__, :rescan)
  end

  # GenServer callbacks

  @impl true
  def init({directory, opts}) do
    directories = if is_list(directory), do: directory, else: [directory]
    poll_interval = Keyword.get(opts, :poll_interval, @poll_interval)

    state = %{
      directories: directories,
      recursive: Keyword.get(opts, :recursive, true),
      file_pattern: Keyword.get(opts, :file_pattern, "**/*.ex"),
      exclude_pattern: Keyword.get(opts, :exclude_pattern, nil),
      auto_reload: Keyword.get(opts, :auto_reload, false),
      poll_interval: poll_interval,
      file_mtimes: %{},
      last_update: nil
    }

    # Initialize the code graph
    :ok = CodeGraph.init()

    # Build the initial graph
    build_initial_graph(state)

    # Schedule the first check
    schedule_check(poll_interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      watching: state.directories,
      files_tracked: map_size(state.file_mtimes),
      last_update: state.last_update
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:rescan, state) do
    # Force a full rescan by clearing the file_mtimes
    new_state = %{state | file_mtimes: %{}}
    updated_state = check_files(new_state)

    # Always update the last_update timestamp for rescan operations
    {:noreply, %{updated_state | last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:check_files, state) do
    new_state = check_files(state)
    schedule_check(state.poll_interval)
    {:noreply, new_state}
  end

  # Private functions

  defp build_initial_graph(state) do
    Enum.each(state.directories, fn dir ->
      opts = [
        recursive: state.recursive,
        file_pattern: state.file_pattern,
        exclude_pattern: state.exclude_pattern
      ]

      case CodeGraph.build_graph(dir, opts) do
        {:ok, stats} ->
          Logger.info(
            "Built initial code graph for #{dir}: " <>
              "#{stats.modules} modules, #{stats.functions} functions, " <>
              "#{stats.relationships} relationships"
          )

        {:error, reason} ->
          Logger.error("Failed to build initial graph for #{dir}: #{inspect(reason)}")
      end
    end)
  end

  defp check_files(state) do
    # Get all files matching the pattern in all directories
    all_files =
      Enum.flat_map(state.directories, fn dir ->
        pattern =
          if state.recursive do
            Path.join(dir, state.file_pattern)
          else
            # Handle non-recursive case
            Path.join(dir, Path.basename(state.file_pattern))
          end

        Path.wildcard(pattern)
      end)

    # Filter out excluded files
    files =
      if state.exclude_pattern do
        exclude_paths = Path.wildcard(state.exclude_pattern)
        Enum.reject(all_files, &(&1 in exclude_paths))
      else
        all_files
      end

    # Get current file modification times
    current_mtimes = get_mtimes(files)

    # Get deleted files (in old state but not in current files)
    deleted_files = Map.keys(state.file_mtimes) -- Map.keys(current_mtimes)

    # Get new or modified files
    new_or_modified =
      Enum.filter(files, fn file ->
        case {Map.get(current_mtimes, file), Map.get(state.file_mtimes, file)} do
          {current, old} when is_nil(old) or current > old ->
            true

          _ ->
            false
        end
      end)

    # Process changes
    changed = process_file_changes(new_or_modified, deleted_files, state)

    # Update state with new mtimes and last_update timestamp
    %{
      state
      | file_mtimes: current_mtimes,
        last_update:
          if changed or Enum.any?(new_or_modified) or Enum.any?(deleted_files) do
            # Force update of the timestamp when any files have been modified or deleted
            # Add a small delay to ensure the timestamp is different from previous timestamps
            # Small delay to ensure timestamp is different
            Process.sleep(10)
            DateTime.utc_now()
          else
            state.last_update
          end
    }
  end

  defp get_mtimes(files) do
    Enum.reduce(files, %{}, fn file, acc ->
      case File.stat(file, time: :posix) do
        {:ok, %{mtime: mtime}} -> Map.put(acc, file, mtime)
        {:error, _} -> acc
      end
    end)
  end

  defp process_file_changes(new_or_modified, deleted, state) do
    # Track if any changes were made
    changed_count = 0

    # Process new or modified files
    changed_count =
      Enum.reduce(new_or_modified, changed_count, fn file, count ->
        if process_changed_file(file, state) do
          count + 1
        else
          count
        end
      end)

    # Process deleted files (if needed)
    deleted_count = Enum.count(deleted)

    Enum.each(deleted, fn file ->
      Logger.debug("File deleted: #{file}")
      # We might want to handle deleted files differently
    end)

    # Return true if any changes were made
    changed_count > 0 or deleted_count > 0
  end

  defp process_changed_file(file, state) do
    Logger.debug("Updating graph for changed file: #{file}")

    # Update the code graph with the changed file
    case CodeGraph.update_file(file) do
      {:ok, stats} ->
        Logger.info(
          "Updated graph for #{file}: " <>
            "#{stats.modules} modules, #{stats.functions} functions"
        )

        # If auto-reload is enabled, reload the modules
        if state.auto_reload do
          reload_modules_in_file(file)
        end

        # Return true to indicate a change was processed
        true

      {:error, reason} ->
        Logger.error("Failed to update graph for #{file}: #{inspect(reason)}")
        # Return false to indicate no change was processed
        false
    end
  end

  defp reload_modules_in_file(file) do
    try do
      # Load the file content
      {:ok, content} = File.read(file)

      # Parse the file to find module names
      {:ok, ast} = Code.string_to_quoted(content)

      # Extract module names from the AST
      modules = extract_modules_from_ast(ast)

      # Reload each module
      Enum.each(modules, fn module_name ->
        module = String.to_atom("Elixir.#{module_name}")

        if Code.ensure_loaded?(module) do
          Logger.debug("Reloading module: #{module_name}")
          :code.purge(module)
          :code.load_file(module)
        end
      end)
    rescue
      e -> Logger.error("Error reloading modules from #{file}: #{inspect(e)}")
    end
  end

  defp extract_modules_from_ast(ast) do
    {_, modules} =
      Macro.traverse(
        ast,
        [],
        fn
          {:defmodule, _, [{:__aliases__, _, module_parts} | _]} = ast, acc ->
            module_name = Enum.map_join(module_parts, ".", &to_string/1)
            {ast, [module_name | acc]}

          ast, acc ->
            {ast, acc}
        end,
        fn ast, acc -> {ast, acc} end
      )

    modules
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check_files, interval)
  end
end
