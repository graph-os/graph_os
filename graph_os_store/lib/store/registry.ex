defmodule GraphOS.Store.Registry do
  @moduledoc """
  Registry for managing GraphOS.Store instances.

  This module provides functions for registering and looking up store instances
  by name, allowing for multiple stores to coexist in the same application.
  It also provides a registry for entity types, allowing custom entity modules
  to register their entity type.
  """

  use GenServer

  @type adapter_type :: GraphOS.Store.Adapter.ETS # We only support ETS for now

  defguard is_adapter_type(adapter_type) when adapter_type in [GraphOS.Store.Adapter.ETS]

  @doc """
  Starts the registry server.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, name: __MODULE__)
  end

  @doc """
  Registers a store name with a store reference and adapter.
  """
  @spec register(atom(), any(), module()) :: :ok
  def register(name, store_ref, adapter) do
    GenServer.call(__MODULE__, {:register, name, {store_ref, adapter}})
  end

  @doc """
  Unregisters a store name.
  """
  @spec unregister(atom()) :: :ok
  def unregister(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc """
  Looks up a store by name and returns the store ref and adapter.
  """
  @spec lookup(atom()) :: {:ok, any(), module()} | {:error, :not_found}
  def lookup(name) do
    case GenServer.call(__MODULE__, {:lookup, name}) do
      {store_ref, adapter} when not is_nil(adapter) -> {:ok, store_ref, adapter}
      _ -> {:error, :not_found}
    end
  end

  # Server callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, name, {store_ref, adapter}}, _from, state) do
    {:reply, :ok, Map.put(state, name, {store_ref, adapter})}
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    {:reply, :ok, Map.delete(state, name)}
  end

  @impl true
  def handle_call({:lookup, name}, _from, state) do
    case Map.get(state, name) do
      {store_ref, adapter} -> {:reply, {store_ref, adapter}, state}
      _ -> {:reply, {:error, :not_found}, state}
    end
  end
end
