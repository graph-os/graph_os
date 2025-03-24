defmodule GraphOS.Dev.GitIntegration do
  @moduledoc """
  Integration with Git repositories to track branches, commits, and file changes.
  Provides APIs to detect repository information and track changes over time.
  """

  require Logger

  @doc """
  Detect Git repository information for a given directory path.

  ## Parameters

  - `path` - Path to a directory within a Git repository

  ## Returns

  A map containing:
  - `:repo_path` - The root path of the repository
  - `:current_branch` - The currently checked out branch
  - `:remote_url` - The URL of the remote repository (if available)
  """
  @spec repository_info(Path.t()) :: {:ok, map()} | {:error, term()}
  def repository_info(path) do
    with {:ok, repo_path} <- get_repo_root(path),
         {:ok, current_branch} <- get_current_branch(repo_path),
         {:ok, remote_url} <- get_remote_url(repo_path) do
      {:ok,
       %{
         repo_path: repo_path,
         current_branch: current_branch,
         remote_url: remote_url
       }}
    end
  end

  @doc """
  Get a list of all branches in the repository.

  ## Parameters

  - `repo_path` - Path to the Git repository

  ## Returns

  A list of branch names.
  """
  @spec list_branches(Path.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_branches(repo_path) do
    case System.cmd("git", ["--no-pager", "branch", "--list", "--format=%(refname:short)"],
           cd: repo_path
         ) do
      {output, 0} ->
        branches =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)

        {:ok, branches}

      {error, code} ->
        {:error, "Failed to list branches (#{code}): #{error}"}
    end
  end

  @doc """
  Get commit information for a specific branch.

  ## Parameters

  - `repo_path` - Path to the Git repository
  - `branch` - Branch name (defaults to current branch)
  - `limit` - Maximum number of commits to return

  ## Returns

  A list of commits with their metadata.
  """
  @spec get_commits(Path.t(), String.t() | nil, integer()) :: {:ok, [map()]} | {:error, term()}
  def get_commits(repo_path, branch \\ nil, limit \\ 10) do
    branch_arg = if branch, do: branch, else: "HEAD"

    case System.cmd(
           "git",
           [
             "--no-pager",
             "log",
             branch_arg,
             "-n",
             "#{limit}",
             "--pretty=format:%H|%an|%ae|%at|%s"
           ],
           cd: repo_path
         ) do
      {output, 0} ->
        commits =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            [hash, author, email, timestamp, subject] = String.split(line, "|", parts: 5)
            timestamp = String.to_integer(timestamp)
            datetime = DateTime.from_unix!(timestamp)

            %{
              hash: hash,
              author: author,
              email: email,
              timestamp: datetime,
              subject: subject
            }
          end)

        {:ok, commits}

      {error, code} ->
        {:error, "Failed to get commits (#{code}): #{error}"}
    end
  end

  @doc """
  Get the list of files changed in a specific commit.

  ## Parameters

  - `repo_path` - Path to the Git repository
  - `commit_hash` - Hash of the commit to analyze

  ## Returns

  A list of changed files with their status.
  """
  @spec get_changed_files(Path.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_changed_files(repo_path, commit_hash) do
    case System.cmd(
           "git",
           ["--no-pager", "show", "--name-status", "--format=", commit_hash],
           cd: repo_path
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            [status, path] = String.split(line, "\t", parts: 2)

            change_type =
              case status do
                "A" -> :added
                "M" -> :modified
                "D" -> :deleted
                "R" -> :renamed
                _ -> :unknown
              end

            %{
              path: path,
              change_type: change_type
            }
          end)

        {:ok, files}

      {error, code} ->
        {:error, "Failed to get changed files (#{code}): #{error}"}
    end
  end

  @doc """
  Get blame information for a specific file, showing which commit last modified each line.

  ## Parameters

  - `repo_path` - Path to the Git repository
  - `file_path` - Path to the file, relative to repo root
  - `options` - Options for the blame operation

  ## Returns

  A list of line entries with commit information.
  """
  @spec blame(Path.t(), Path.t(), Keyword.t()) :: {:ok, [map()]} | {:error, term()}
  def blame(repo_path, file_path, options \\ []) do
    args = ["--no-pager", "blame", "--porcelain"]

    # Add options
    args =
      if Keyword.get(options, :line_range) do
        {start_line, end_line} = Keyword.get(options, :line_range)
        args ++ ["-L", "#{start_line},#{end_line}"]
      else
        args
      end

    # Add file path
    args = args ++ [file_path]

    case System.cmd("git", args, cd: repo_path) do
      {output, 0} ->
        # Parse the porcelain output
        lines = parse_blame_porcelain(output)
        {:ok, lines}

      {error, code} ->
        {:error, "Failed to get blame info (#{code}): #{error}"}
    end
  end

  @doc """
  Set up a file system watcher to monitor Git repository events.

  ## Parameters

  - `repo_path` - Path to the Git repository
  - `callback` - Function to call when Git events occur

  ## Returns

  The PID of the watcher process.
  """
  @spec watch_repository(Path.t(), (map() -> any())) :: {:ok, pid()} | {:error, term()}
  def watch_repository(repo_path, callback) do
    # Start a process that periodically checks for Git changes
    {:ok, pid} =
      Task.start_link(fn ->
        watch_loop(repo_path, callback, %{
          current_branch: nil,
          head_commit: nil
        })
      end)

    {:ok, pid}
  end

  # Private functions

  defp get_repo_root(path) do
    case System.cmd("git", ["rev-parse", "--show-toplevel"], cd: path) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, code} -> {:error, "Failed to get repo root (#{code}): #{error}"}
    end
  end

  @doc """
  Get the current branch for a repository.

  ## Parameters

  - `repo_path` - Path to the Git repository

  ## Returns

  The name of the current branch.
  """
  @spec get_current_branch(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def get_current_branch(repo_path) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], cd: repo_path) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, code} -> {:error, "Failed to get current branch (#{code}): #{error}"}
    end
  end

  defp get_remote_url(repo_path) do
    case System.cmd("git", ["config", "--get", "remote.origin.url"], cd: repo_path) do
      {output, 0} -> {:ok, String.trim(output)}
      # No remote or no origin, not an error
      {_, _} -> {:ok, nil}
    end
  end

  defp get_head_commit(repo_path) do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: repo_path) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, code} -> {:error, "Failed to get HEAD commit (#{code}): #{error}"}
    end
  end

  defp parse_blame_porcelain(output) do
    # Split the output into chunks, each starting with a commit line
    lines = String.split(output, "\n", trim: true)

    # Group the lines into chunks by commit
    {_, result} =
      Enum.reduce(lines, {nil, []}, fn line, {current_chunk, acc} ->
        cond do
          # New commit line starts with the commit hash
          String.match?(line, ~r/^[0-9a-f]{40}/) ->
            [hash | _rest] = String.split(line, " ", trim: true)

            # Parse the header line
            chunk = %{
              hash: hash,
              line_number: nil,
              content: nil,
              author: nil,
              timestamp: nil
            }

            {chunk, acc}

          # Author line
          String.starts_with?(line, "author ") ->
            author = String.replace_prefix(line, "author ", "")
            {Map.put(current_chunk, :author, author), acc}

          # Author time line
          String.starts_with?(line, "author-time ") ->
            timestamp_str = String.replace_prefix(line, "author-time ", "")
            timestamp = String.to_integer(timestamp_str)
            datetime = DateTime.from_unix!(timestamp)
            {Map.put(current_chunk, :timestamp, datetime), acc}

          # Content line (starts with a tab)
          String.starts_with?(line, "\t") ->
            content = String.replace_prefix(line, "\t", "")

            # Complete the chunk and add to accumulator
            chunk = Map.put(current_chunk, :content, content)
            {nil, [chunk | acc]}

          # Line number
          String.match?(line, ~r/^\d+/) ->
            [line_number | _] = String.split(line, " ", trim: true)
            {Map.put(current_chunk, :line_number, String.to_integer(line_number)), acc}

          # Other lines we ignore
          true ->
            {current_chunk, acc}
        end
      end)

    # Return the result in reverse order (to maintain original file order)
    Enum.reverse(result)
  end

  defp watch_loop(repo_path, callback, state) do
    # Check current branch
    {:ok, current_branch} = get_current_branch(repo_path)
    {:ok, head_commit} = get_head_commit(repo_path)

    # Detect changes
    cond do
      # Branch has changed
      state.current_branch != nil && current_branch != state.current_branch ->
        callback.(%{
          type: :branch_changed,
          previous_branch: state.current_branch,
          current_branch: current_branch
        })

      # New commit
      state.head_commit != nil && head_commit != state.head_commit ->
        # Get commit info
        {:ok, [commit | _]} = get_commits(repo_path, nil, 1)
        # Get changed files
        {:ok, changed_files} = get_changed_files(repo_path, head_commit)

        callback.(%{
          type: :new_commit,
          commit: commit,
          changed_files: changed_files
        })

      # Initial state
      state.current_branch == nil ->
        callback.(%{
          type: :initial,
          current_branch: current_branch,
          head_commit: head_commit
        })

      # No changes
      true ->
        :ok
    end

    # Update state
    new_state = %{
      current_branch: current_branch,
      head_commit: head_commit
    }

    # Sleep and loop
    # Check every 5 seconds
    :timer.sleep(5000)
    watch_loop(repo_path, callback, new_state)
  end
end
