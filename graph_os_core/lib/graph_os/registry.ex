defmodule GraphOS.Registry do
  @moduledoc """
  Registry for GraphOS that manages both servers and connections.
  Provides a centralized way to track and lookup processes.
  """

  @doc """
  Starts the registry.
  """
  def start_link(_opts \\ []) do
    Registry.start_link(keys: :unique, name: __MODULE__, partitions: System.schedulers_online())
  end

  @doc """
  Registers a process in the registry.
  """
  def register(pid, type, metadata \\ %{}) do
    process_id = generate_process_id()

    process_info = %{
      type: type,
      pid: pid,
      metadata: metadata,
      registered_at: DateTime.utc_now()
    }

    case Registry.register(__MODULE__, process_id, process_info) do
      {:ok, _} -> {:ok, process_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Unregister a process from the registry.
  """
  def unregister(pid) do
    case lookup_by_pid(pid) do
      {:ok, process_id} -> Registry.unregister(__MODULE__, process_id)
      error -> error
    end
  end

  @doc """
  Looks up a process by its PID.
  """
  def lookup_by_pid(pid) do
    Registry.select(__MODULE__, [{{:"$1", %{pid: pid}}, [], [:"$1"]}])
    |> case do
      [process_id] -> {:ok, process_id}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a process by its ID.
  """
  def lookup(process_id) do
    case Registry.lookup(__MODULE__, process_id) do
      [{process_info, _}] -> {:ok, process_info}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets all processes of a specific type.
  """
  def by_type(type) do
    Registry.select(__MODULE__, [{{:"$1", %{type: type}}, [], [:"$1"]}])
    |> Enum.map(&lookup/1)
    |> Enum.filter(fn
      {:ok, _} -> true
      {:error, _} -> false
    end)
    |> Enum.map(fn {:ok, info} -> info end)
  end

  @doc """
  Gets all processes that match specific metadata.
  """
  def by_metadata(key, value) do
    Registry.select(__MODULE__, [{{:"$1", %{metadata: %{key => value}}}, [], [:"$1"]}])
    |> Enum.map(&lookup/1)
    |> Enum.filter(fn
      {:ok, _} -> true
      {:error, _} -> false
    end)
    |> Enum.map(fn {:ok, info} -> info end)
  end

  @doc """
  Gets all registered processes.
  """
  def all do
    Registry.select(__MODULE__, [{{:"$1", :_}, [], [:"$1"]}])
    |> Enum.map(&lookup/1)
    |> Enum.filter(fn
      {:ok, _} -> true
      {:error, _} -> false
    end)
    |> Enum.map(fn {:ok, info} -> info end)
  end

  # Private Functions

  defp generate_process_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
