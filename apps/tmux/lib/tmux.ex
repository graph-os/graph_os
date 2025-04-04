defmodule TMUX do
  @moduledoc """
  Utility module for working with tmux sessions.

  This module provides functions to check if tmux is available,
  manage sessions, and interact with them programmatically.
  """

  @doc """
  Checks if tmux is available on the system.

  ## Examples

      iex> TMUX.available?()
      true

  """
  def available? do
    case System.cmd("which", ["tmux"], stderr_to_stdout: true) do
      {_, 0} -> true
      {_, _} -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if a tmux session with the given name exists.

  Uses a simple direct approach for maximum reliability.

  ## Examples

      iex> TMUX.session_exists?("my_session")
      false

  """
  def session_exists?(session_name, _retries \\ 0) do
    # Use a direct simple approach for reliability
    {_, status} = System.cmd("tmux", ["has-session", "-t", session_name], stderr_to_stdout: true)
    status == 0
  rescue
    # In case of any error, assume the session doesn't exist
    _ -> false
  end

  @doc """
  Creates a new tmux session with the given name and options.

  ## Options

  * `:cwd` - Working directory for the session (default: current directory)
  * `:detached` - Whether to create a detached session (default: true)
  * `:env` - Environment variables to set in the session

  ## Examples

      iex> TMUX.create_session("my_session", cwd: "/tmp")
      :ok

  """
  def create_session(session_name, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    detached = Keyword.get(opts, :detached, true)

    args = ["new-session"]
    args = if detached, do: args ++ ["-d"], else: args
    args = args ++ ["-s", session_name, "-c", cwd]

    case System.cmd("tmux", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, status} -> {:error, {status, output}}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Stops (kills) a tmux session with the given name.

  ## Examples

      iex> TMUX.stop_session("my_session")
      :ok

  """
  def stop_session(session_name) do
    case System.cmd("tmux", ["kill-session", "-t", session_name], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, status} -> {:error, {status, output}}
    end
  rescue
    e -> {:error, e}
  end
end
