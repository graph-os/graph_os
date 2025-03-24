defmodule GraphOS.Dev.CodeGraph.Service do
  @moduledoc """
  Service for managing and exposing code graph functionality.

  This module provides server-side functionality for code graph operations,
  including:
  - Managing the graph store
  - Indexing and watching file systems
  - Exposing APIs for graph queries
  - Supporting distributed code search across systems
  - Git integration for repository and branch awareness
  - Cross-graph queries for comparing code across branches
  """

  use GenServer
  require Logger

  alias GraphOS.Dev.CodeGraph
  alias GraphOS.Dev.FileWatcher
  alias GraphOS.Dev.GitIntegration
  # TODO: CrossQuery implementation needs to be moved or reimplemented in GraphOS.Dev

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
  - `:git_enabled` - Whether to enable Git integration (default: true)

  ## Examples

      iex> {:ok, pid} = GraphOS.Dev.CodeGraph.Service.start_link()
      {:ok, #PID<0.123.0>}

      iex> GraphOS.Dev.CodeGraph.Service.start_link(watched_dirs: ["lib", "test"])
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query the code graph by module name.

  ## Parameters

  - `module_name` - The name of the module to query

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.query_module("GraphOS.Dev.CodeGraph")
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

      iex> GraphOS.Dev.CodeGraph.Service.find_implementations("GraphOS.Store.Protocol")
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

      iex> GraphOS.Dev.CodeGraph.Service.find_dependents("GraphOS.Store")
      {:ok, [module_names]}
  """
  @spec find_dependents(String.t()) :: {:ok, list(String.t())} | {:error, term()}
  def find_dependents(module_name) do
    GenServer.call(__MODULE__, {:find_dependents, module_name})
  end

  @doc """
  Get status information about the code graph service.

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.status()
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

      iex> GraphOS.Dev.CodeGraph.Service.subscribe([:file_change, :module_update])
      :ok
  """
  @spec subscribe(list(atom()), pid() | atom()) :: :ok
  def subscribe(event_types \\ [:all], subscriber \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, event_types, subscriber})
  end

  @doc """
  Force a rebuild of the code graph.

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.rebuild()
      :ok
  """
  @spec rebuild() :: :ok
  def rebuild do
    GenServer.cast(__MODULE__, :rebuild)
  end

  @doc """
  Query for code items across multiple branch graphs.

  ## Parameters

  - `query` - Query to execute across graphs
  - `repo_path` - Repository path to limit the query to
  - `opts` - Options for cross-graph query

  ## Options

  - `:branches` - List of branches to query (default: all branches)
  - `:merge_results` - Whether to merge results into a single list (default: false)

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.query_across_branches(%{name: "MyModule"}, "path/to/repo")
      {:ok, %{results_by_branch}}
  """
  @spec query_across_branches(map(), Path.t(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def query_across_branches(query, repo_path, opts \\ []) do
    GenServer.call(__MODULE__, {:query_across_branches, query, repo_path, opts})
  end

  @doc """
  Compare code structure between two branches.

  ## Parameters

  - `repo_path` - Repository path
  - `branch1` - First branch name
  - `branch2` - Second branch name
  - `opts` - Options for comparison

  ## Options

  - `:node_types` - Types of nodes to compare (default: all)
  - `:include_attributes` - Whether to compare attributes (default: true)

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.compare_branches("path/to/repo", "main", "feature-x")
      {:ok, diff_results}
  """
  @spec compare_branches(Path.t(), String.t(), String.t(), Keyword.t()) ::
          {:ok, map()} | {:error, term()}
  def compare_branches(repo_path, branch1, branch2, opts \\ []) do
    GenServer.call(__MODULE__, {:compare_branches, repo_path, branch1, branch2, opts})
  end

  @doc """
  Get a list of all repositories and branches being tracked.

  ## Examples

      iex> GraphOS.Dev.CodeGraph.Service.list_repositories()
      {:ok, [%{repo_path: "...", branches: [...], ...}]}
  """
  @spec list_repositories() :: {:ok, list(map())} | {:error, term()}
  def list_repositories do
    GenServer.call(__MODULE__, :list_repositories)
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
    git_enabled = Keyword.get(opts, :git_enabled, true)

    # Initialize state
    state = %{
      watched_dirs: watched_dirs,
      file_pattern: file_pattern,
      exclude_pattern: exclude_pattern,
      auto_reload: auto_reload,
      poll_interval: poll_interval,
      distributed: distributed,
      node_name: node_name,
      git_enabled: git_enabled,
      subscribers: %{},
      file_watcher_pid: nil,
      git_watchers: %{},
      stores: %{},
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

    # Log the fact that StoreAdapter.Supervisor and CrossQuery aren't implemented yet
    Logger.warning("StoreAdapter.Supervisor/CrossQuery functionality not fully implemented")

    # Start a basic registry system for backward compatibility
    start_store_system()

    # Detect repositories in watched directories
    state = if git_enabled, do: detect_repositories(state), else: state

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
  def handle_call({:query_across_branches, _query, _repo_path, _opts}, _from, state) do
    # TODO: Implement cross-branch query functionality
    # This would require moving or reimplementing the CrossQuery module
    result = {:error, "Cross-branch query functionality not implemented"}
    {:reply, result, state}
  end

  @impl true
  def handle_call({:compare_branches, _repo_path, _branch1, _branch2, _opts}, _from, state) do
    # TODO: Implement branch comparison functionality
    # This would require moving or reimplementing the CrossQuery module
    result = {:error, "Branch comparison functionality not implemented"}
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_repositories, _from, state) do
    # List repositories
    result = Enum.map(state.git_watchers, fn {repo_path, _} -> %{repo_path: repo_path} end)
    {:reply, {:ok, result}, state}
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
      if Enum.member?(event_types, :all) do
        updated_subscribers
      else
        all_subscribers = Map.get(updated_subscribers, :all, [])
        Map.put(updated_subscribers, :all, [subscriber | all_subscribers])
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
      Enum.reduce(
        state.watched_dirs,
        %{modules: 0, functions: 0, relationships: 0, files: 0},
        fn dir, acc ->
          case CodeGraph.build_graph(dir,
                 recursive: true,
                 file_pattern: state.file_pattern,
                 exclude_pattern: state.exclude_pattern
               ) do
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
        end
      )

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

  @impl true
  def handle_info({:git_event, repo_path, event}, state) do
    # Process Git events
    Logger.debug("Received Git event for #{repo_path}: #{inspect(event.type)}")

    case event.type do
      :branch_changed ->
        # Branch has changed, update the current branch in state
        handle_branch_change(repo_path, event.previous_branch, event.current_branch, state)

      :new_commit ->
        # New commit detected, process changed files
        handle_new_commit(repo_path, event.commit, event.changed_files, state)

      :initial ->
        # Initial repository detection
        Logger.info("Initialized Git tracking for #{repo_path} on branch #{event.current_branch}")

      _ ->
        Logger.warning("Unknown Git event type: #{inspect(event.type)}")
    end

    {:noreply, state}
  end

  # Helper methods to handle git events

  defp handle_branch_change(repo_path, previous_branch, current_branch, state) do
    Logger.info("Branch changed in #{repo_path} from #{previous_branch} to #{current_branch}")

    # Get the store for the current branch or create it if it doesn't exist
    current_store = get_branch_store(repo_path, current_branch, state)

    # Notify subscribers
    notify_subscribers(state, :branch_change, %{
      repo_path: repo_path,
      previous_branch: previous_branch,
      current_branch: current_branch
    })

    # Rebuild the graph for this branch
    rebuild_branch_graph(repo_path, current_branch, current_store)
  end

  defp handle_new_commit(repo_path, commit, changed_files, state) do
    Logger.info("New commit in #{repo_path}: #{commit.hash} - #{commit.subject}")

    # Get the store for the current branch
    {:ok, current_branch} = GitIntegration.get_current_branch(repo_path)
    current_store = get_branch_store(repo_path, current_branch, state)

    # Process only changed source files
    source_files =
      changed_files
      |> Enum.filter(fn file ->
        String.ends_with?(file.path, ".ex") || String.ends_with?(file.path, ".exs")
      end)

    # Update the graph with changed files
    update_graph_with_files(repo_path, current_store, source_files, commit)

    # Notify subscribers
    notify_subscribers(state, :commit, %{
      repo_path: repo_path,
      branch: current_branch,
      commit: commit,
      changed_files: changed_files
    })
  end

  defp get_branch_store(repo_path, branch, state) do
    store_key = "branch:#{repo_path}:#{branch}"

    case Map.get(state.stores, store_key) do
      nil ->
        # TODO: Implement store supervisor and management
        # This would require implementing a GraphOS.Dev.Graph.StoreAdapter module
        # For now, return a placeholder
        Logger.warning("StoreAdapter functionality not fully implemented for branch #{branch}")
        :not_implemented

      store_pid ->
        store_pid
    end
  end

  defp rebuild_branch_graph(_repo_path, _branch, _store) do
    # TODO: Implement store clearing and rebuilding
    # This would require implementing GraphOS.Dev.Graph.StoreAdapter.Server

    Logger.warning("Branch graph rebuilding not fully implemented")
    :ok
  end

  defp update_graph_with_files(repo_path, store, changed_files, commit) do
    Enum.each(changed_files, fn file ->
      file_path = Path.join(repo_path, file.path)

      case file.change_type do
        :added ->
          # Parse and add new file
          process_file_for_store(file_path, store, commit)

        :modified ->
          # Update existing file
          # First remove existing nodes for this file
          remove_file_from_store(file_path, store)
          # Then add updated file
          process_file_for_store(file_path, store, commit)

        :deleted ->
          # Remove file from graph
          remove_file_from_store(file_path, store)

        _ ->
          Logger.warning("Unhandled change type #{file.change_type} for #{file_path}")
      end
    end)
  end

  defp process_file_for_store(file_path, store, commit) do
    # Parse the file
    case GraphOS.Dev.CodeParser.parse_file(file_path) do
      {:ok, parsed_data} ->
        # Add to the store with Git metadata
        add_to_store(parsed_data, file_path, store, commit)

      {:error, reason} ->
        Logger.error("Failed to parse file #{file_path}: #{inspect(reason)}")
    end
  end

  defp remove_file_from_store(_file_path, _store) do
    # Remove all nodes associated with this file from the store
    # Ideally this would use a query to find all nodes for the file
    # and then remove them, but we'll need to implement that in the store
    :ok
  end

  defp add_to_store(_parsed_data, _file_path, _store, _commit) do
    # Add parsed data to the store with git metadata
    # This would require modification to the existing add_to_graph function
    # to work with a specific store and add commit metadata
    :ok
  end

  # Private functions

  defp start_file_watcher(state) do
    if Enum.empty?(state.watched_dirs) do
      Logger.info("No directories specified for watching. File watching disabled.")
      nil
    else
      # Start the file watcher
      case FileWatcher.start_link(state.watched_dirs,
             recursive: true,
             file_pattern: state.file_pattern,
             exclude_pattern: state.exclude_pattern,
             auto_reload: state.auto_reload,
             poll_interval: state.poll_interval
           ) do
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

  defp start_store_system do
    # TODO: Implement properly with GraphOS.Dev.Graph.StoreAdapter
    Logger.info("Initializing basic registry for store system")

    # Just start a basic registry for now
    children = [
      {Registry, keys: :unique, name: GraphOS.Store.StoreAdapterRegistry}
    ]

    # Start supervisor without linking (we're inside GenServer init)
    {:ok, _pid} =
      Supervisor.start_link(children,
        strategy: :one_for_one,
        name: GraphOS.Dev.StoreAdapterSystem
      )

    :ok
  end

  defp detect_repositories(state) do
    # Scan watched directories for Git repositories
    repositories =
      state.watched_dirs
      |> Enum.flat_map(fn dir ->
        case GitIntegration.repository_info(dir) do
          {:ok, repo_info} ->
            # Create a store for this repository
            repo_store = get_or_create_repo_store(repo_info.repo_path)

            # Get available branches
            {:ok, branches} = GitIntegration.list_branches(repo_info.repo_path)

            # Create stores for each branch
            branch_stores = create_branch_stores(repo_info.repo_path, branches)

            # Start a Git watcher for this repository
            {:ok, watcher_pid} =
              GitIntegration.watch_repository(
                repo_info.repo_path,
                &handle_git_event(&1, repo_info.repo_path)
              )

            # Return repository info with stores
            [
              %{
                repo_path: repo_info.repo_path,
                current_branch: repo_info.current_branch,
                remote_url: repo_info.remote_url,
                repo_store: repo_store,
                branch_stores: branch_stores,
                watcher_pid: watcher_pid
              }
            ]

          {:error, _} ->
            # Not a Git repository, ignore
            []
        end
      end)
      |> Enum.into(%{}, fn repo -> {repo.repo_path, repo} end)

    # Update state with repository information
    watchers =
      repositories
      |> Enum.map(fn {repo_path, repo} -> {repo_path, repo.watcher_pid} end)
      |> Enum.into(%{})

    stores =
      repositories
      |> Enum.flat_map(fn {repo_path, repo} ->
        # Add repo store
        repo_store = [{"repo:#{repo_path}", repo.repo_store}]

        # Add branch stores
        branch_stores =
          Enum.map(repo.branch_stores, fn {branch, store} ->
            {"branch:#{repo_path}:#{branch}", store}
          end)

        repo_store ++ branch_stores
      end)
      |> Enum.into(%{})

    %{state | git_watchers: watchers, stores: stores}
  end

  defp get_or_create_repo_store(_repo_path) do
    # TODO: Implement store creation and management
    Logger.warning("Repository store functionality not fully implemented")
    :not_implemented
  end

  defp create_branch_stores(repo_path, branches) do
    # TODO: Implement branch store creation
    Logger.warning("Branch store functionality not fully implemented for #{repo_path}")

    # Return an empty map for now
    branches
    |> Enum.map(fn branch -> {branch, :not_implemented} end)
    |> Enum.into(%{})
  end

  # Handle Git events from repository watchers
  defp handle_git_event(event, repo_path) do
    # Send event to the service process
    send(self(), {:git_event, repo_path, event})
  end
end
