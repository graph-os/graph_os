defmodule GraphOS.Core.CodeGraph.Service do
  @moduledoc """
  Service for managing and exposing code graph functionality.

  This module provides server-side functionality for code graph operations,
  including:
  - Managing the graph store
  - Indexing and watching file systems
  - Exposing APIs for graph queries
  - Supporting distributed code search across systems
  """

  use GenServer
  require Logger

  alias GraphOS.Core.CodeGraph
  alias GraphOS.Core.FileWatcher

  # Public API

  @doc """
  Start the code graph service.

  ## Parameters

  - `opts` - Options for the service

  ## Options

  - `:watched_dirs` - Directories to watch for changes (default: ["lib"])
  - `:file_pattern` - Pattern for files to include (default: "**/*.ex")
  - `:exclude_pattern` - Pattern for files to exclude (default: nil)
  - `:auto_reload` - Whether to automatically reload modules on change (default: false)
  - `:poll_interval` - File watch polling interval in ms (default: 1000)
  - `:distributed` - Whether to enable distributed graph features (default: true)
  - `:node_name` - Identifier for this node in distributed setup (default: node name)

  ## Examples

      iex> {:ok, pid} = GraphOS.Core.CodeGraph.Service.start_link()
      {:ok, #PID<0.123.0>}

      iex> GraphOS.Core.CodeGraph.Service.start_link(watched_dirs: ["lib", "test"])
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query the code graph by module name.

  ## Parameters

  - `module_name` - The name of the module to query

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.query_module("GraphOS.Core.CodeGraph")
      {:ok, module_info}
  """
  @spec query_module(String.t()) :: {:ok, map()} | {:error, term()}
  def query_module(module_name) do
    GenServer.call(__MODULE__, {:query_module, module_name})
  end

  @doc """
  Find modules that implement a specific protocol or behaviour.

  ## Parameters

  - `protocol_or_behaviour` - The name of the protocol or behaviour

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.find_implementations("GraphOS.Graph.Protocol")
      {:ok, [module_names]}
  """
  @spec find_implementations(String.t()) :: {:ok, list(String.t())} | {:error, term()}
  def find_implementations(protocol_or_behaviour) do
    GenServer.call(__MODULE__, {:find_implementations, protocol_or_behaviour})
  end

  @doc """
  Find modules that depend on a specific module.

  ## Parameters

  - `module_name` - The name of the module

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.find_dependents("GraphOS.Graph")
      {:ok, [module_names]}
  """
  @spec find_dependents(String.t()) :: {:ok, list(String.t())} | {:error, term()}
  def find_dependents(module_name) do
    GenServer.call(__MODULE__, {:find_dependents, module_name})
  end

  @doc """
  Get status information about the code graph service.

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.status()
      {:ok, %{watched_dirs: ["lib"], indexed_modules: 42, ...}}
  """
  @spec status() :: {:ok, map()} | {:error, term()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get notifications when specific events occur in the code graph.

  ## Parameters

  - `event_types` - List of event types to subscribe to (default: [:all])
  - `subscriber` - PID or name to receive notifications (default: self())

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.subscribe([:file_change, :module_update])
      :ok
  """
  @spec subscribe(list(atom()), pid() | atom()) :: :ok
  def subscribe(event_types \\ [:all], subscriber \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, event_types, subscriber})
  end

  @doc """
  Force a rebuild of the code graph.

  ## Examples

      iex> GraphOS.Core.CodeGraph.Service.rebuild()
      :ok
  """
  @spec rebuild() :: :ok
  def rebuild do
    GenServer.cast(__MODULE__, :rebuild)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Extract options with defaults
    watched_dirs = Keyword.get(opts, :watched_dirs, ["lib"])
    file_pattern = Keyword.get(opts, :file_pattern, "**/*.ex")
    exclude_pattern = Keyword.get(opts, :exclude_pattern)
    auto_reload = Keyword.get(opts, :auto_reload, false)
    poll_interval = Keyword.get(opts, :poll_interval, 1000)
    distributed = Keyword.get(opts, :distributed, true)
    node_name = Keyword.get(opts, :node_name, node())

    # Initialize state
    state = %{
      watched_dirs: watched_dirs,
      file_pattern: file_pattern,
      exclude_pattern: exclude_pattern,
      auto_reload: auto_reload,
      poll_interval: poll_interval,
      distributed: distributed,
      node_name: node_name,
      subscribers: %{},
      file_watcher_pid: nil,
      index_stats: %{
        modules: 0,
        functions: 0,
        files: 0,
        relationships: 0,
        last_update: nil
      }
    }

    # Initialize the graph
    :ok = CodeGraph.init()

    # Start file watcher if directories are provided
    file_watcher_pid = start_file_watcher(state)

    # Schedule initial build
    send(self(), :initial_build)

    # Return initialized state
    {:ok, %{state | file_watcher_pid: file_watcher_pid}}
  end

  @impl true
  def handle_call({:query_module, module_name}, _from, state) do
    result = CodeGraph.get_module_info(module_name)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:find_implementations, protocol_or_behaviour}, _from, state) do
    result = CodeGraph.find_implementations(protocol_or_behaviour)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:find_dependents, module_name}, _from, state) do
    result = CodeGraph.find_dependents(module_name)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    # Get watcher status if available
    watcher_status =
      if state.file_watcher_pid do
        try do
          FileWatcher.status()
        catch
          _, _ -> %{files_tracked: 0, last_update: nil}
        end
      else
        %{files_tracked: 0, last_update: nil}
      end

    # Combine with service status
    status = %{
      watched_dirs: state.watched_dirs,
      file_pattern: state.file_pattern,
      exclude_pattern: state.exclude_pattern,
      auto_reload: state.auto_reload,
      distributed: state.distributed,
      node_name: state.node_name,
      files_tracked: watcher_status.files_tracked,
      last_update: watcher_status.last_update,
      modules: state.index_stats.modules,
      functions: state.index_stats.functions,
      relationships: state.index_stats.relationships
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:subscribe, event_types, subscriber}, state) do
    # Add subscriber to each event type
    updated_subscribers =
      Enum.reduce(event_types, state.subscribers, fn event_type, acc ->
        subscribers = Map.get(acc, event_type, [])
        Map.put(acc, event_type, [subscriber | subscribers])
      end)

    # Add to :all events if not already included
    updated_subscribers =
      if :all not in event_types do
        all_subscribers = Map.get(updated_subscribers, :all, [])
        Map.put(updated_subscribers, :all, [subscriber | all_subscribers])
      else
        updated_subscribers
      end

    {:noreply, %{state | subscribers: updated_subscribers}}
  end

  @impl true
  def handle_cast(:rebuild, state) do
    # Stop existing file watcher if any
    if state.file_watcher_pid do
      try do
        FileWatcher.stop()
      catch
        _, _ -> :ok
      end
    end

    # Restart the file watcher
    file_watcher_pid = start_file_watcher(state)

    # Trigger a rebuild
    send(self(), :initial_build)

    {:noreply, %{state | file_watcher_pid: file_watcher_pid}}
  end

  @impl true
  def handle_info(:initial_build, state) do
    # Build the graph for each watched directory
    stats =
      Enum.reduce(state.watched_dirs, %{modules: 0, functions: 0, relationships: 0, files: 0}, fn dir, acc ->
        case CodeGraph.build_graph(dir, [
          recursive: true,
          file_pattern: state.file_pattern,
          exclude_pattern: state.exclude_pattern
        ]) do
          {:ok, dir_stats} ->
            # Combine stats
            %{
              modules: acc.modules + dir_stats.modules,
              functions: acc.functions + dir_stats.functions,
              relationships: acc.relationships + dir_stats.relationships,
              files: acc.files + dir_stats.processed_files
            }

          {:error, reason} ->
            Logger.error("Failed to build graph for #{dir}: #{inspect(reason)}")
            acc
        end
      end)

    # Update index stats
    index_stats = Map.merge(state.index_stats, Map.put(stats, :last_update, DateTime.utc_now()))

    # Notify subscribers of index completion
    notify_subscribers(:index_complete, index_stats, state.subscribers)

    # If in distributed mode, announce availability to other nodes
    if state.distributed do
      announce_availability()
    end

    {:noreply, %{state | index_stats: index_stats}}
  end

  @impl true
  def handle_info({:file_change, file_path, change_type}, state) do
    # Handle file change notifications from the watcher
    # (This would be set up with the FileWatcher to forward events)
    Logger.debug("File change detected: #{change_type} - #{file_path}")

    # Notify subscribers
    notify_subscribers(:file_change, %{file: file_path, type: change_type}, state.subscribers)

    {:noreply, state}
  end

  # Private functions

  defp start_file_watcher(state) do
    if Enum.empty?(state.watched_dirs) do
      Logger.info("No directories specified for watching. File watching disabled.")
      nil
    else
      # Start the file watcher
      case FileWatcher.start_link(state.watched_dirs, [
        recursive: true,
        file_pattern: state.file_pattern,
        exclude_pattern: state.exclude_pattern,
        auto_reload: state.auto_reload,
        poll_interval: state.poll_interval
      ]) do
        {:ok, pid} ->
          Logger.info("Started file watcher for: #{inspect(state.watched_dirs)}")
          pid

        {:error, reason} ->
          Logger.error("Failed to start file watcher: #{inspect(reason)}")
          nil
      end
    end
  end

  defp notify_subscribers(event_type, data, subscribers) do
    # Get subscribers for this event type
    event_subscribers = Map.get(subscribers, event_type, [])
    # Get subscribers for all events
    all_subscribers = Map.get(subscribers, :all, [])
    # Combine lists
    all_recipients = event_subscribers ++ all_subscribers

    # Send notification to all subscribers
    Enum.each(all_recipients, fn subscriber ->
      try do
        send(subscriber, {:code_graph_event, event_type, data})
      catch
        _, _ -> :ok
      end
    end)
  end

  defp announce_availability do
    # Broadcast availability to other nodes in the cluster
    # This is a placeholder for distributed functionality
    node_name = node()
    Logger.info("Announcing CodeGraph service availability on node #{node_name}")

    # In a real implementation, this might use Phoenix.PubSub or similar
    # to announce the service to other nodes
    :ok
  end
end
