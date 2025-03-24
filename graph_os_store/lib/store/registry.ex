defmodule GraphOS.Store.Registry do
  @moduledoc """
  Registry for managing GraphOS.Store instances.

  This module provides functions for registering and looking up store instances
  by name, allowing for multiple stores to coexist in the same application.
  """

  use GenServer

  @table_name :graph_os_store_registry

  @doc """
  Starts the registry server.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Registers a store with the given name.
  """
  @spec register(atom(), term(), module()) :: :ok
  def register(name, store_ref, adapter) do
    GenServer.call(__MODULE__, {:register, name, store_ref, adapter})
  end

  @doc """
  Unregisters a store with the given name.
  """
  @spec unregister(atom()) :: :ok
  def unregister(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc """
  Looks up a store by name.
  """
  @spec lookup(atom()) :: {:ok, term(), module()} | {:error, :not_found}
  def lookup(name) do
    case :ets.lookup(@table_name, name) do
      [{^name, store_ref, adapter}] -> {:ok, store_ref, adapter}
      [] -> {:error, :not_found}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  # Server callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table_name, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, name, store_ref, adapter}, _from, state) do
    :ets.insert(@table_name, {name, store_ref, adapter})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    :ets.delete(@table_name, name)
    {:reply, :ok, state}
  end
end
