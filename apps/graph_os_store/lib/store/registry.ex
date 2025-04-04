defmodule GraphOS.Store.Registry do
  @moduledoc """
  A registry for mapping store names to their corresponding adapter process PIDs.

  Store names can be atoms (typically for compile-time defined stores) or
  other terms (like strings or PIDs for dynamically started stores).
  """

  @doc """
  Starts the registry.

  This should typically be called from your application's supervision tree.
  """
  def start_link(_opts \\ []) do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  Registers a store adapter process with a given name.
  """
  @spec register(name :: term(), pid :: pid()) :: {:ok, pid} | {:error, {:already_registered, pid}}
  def register(name, pid) when is_pid(pid) do
    Registry.register(__MODULE__, name, pid)
  end

  @doc """
  Unregisters a store by name.
  """
  @spec unregister(name :: term()) :: :ok | :error
  def unregister(name) do
    Registry.unregister(__MODULE__, name)
  end

  @doc """
  Looks up the PID of a registered store by name.
  """
  @spec lookup(name :: term()) :: [{pid, term()}] | []
  def lookup(name) do
    Registry.lookup(__MODULE__, name)
  end

  @doc """
  Looks up the PID of a registered store by name, raising an error if not found.
  """
  @spec lookup!(name :: term()) :: pid
  def lookup!(name) do
    case lookup(name) do
      [{pid, _}] -> pid
      [] -> raise "Store with name #{inspect(name)} not found in registry"
    end
  end

  # --- GenServer :via Callbacks ---

  @doc false
  # Called by GenServer when registering the process via {:via, __MODULE__, name}
  def register_name(name, pid) do
    case Registry.register(__MODULE__, name, pid) do
      {:ok, _pid} -> :yes
      {:error, {:already_registered, _pid}} -> :no
    end
  end

  @doc false
  # Called by GenServer when unregistering the process
  def unregister_name(name) do
    Registry.unregister(__MODULE__, name)
  end

  @doc false
  # Called by GenServer to find the PID associated with the name
  def whereis_name(name) do
    case Registry.lookup(__MODULE__, name) do
      [{pid, _}] -> pid
      [] -> :undefined
    end
  end

  @doc false
  # Called by GenServer to send a message to the registered process
  def send(name, msg) do
    case Registry.lookup(__MODULE__, name) do
      [{pid, _}] -> Kernel.send(pid, msg)
      [] -> :error # Or raise an error, depending on desired behavior
    end
  end
end
