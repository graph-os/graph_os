defmodule GraphOS.Graph.Storage.ETS do
  @moduledoc """
  ETS-based storage for the graph.

  This module initializes and manages ETS tables for storing graph nodes, edges, and indices.
  """

  use GenServer

  # Table names
  @nodes_table :graph_nodes
  @edges_table :graph_edges
  @indices_table :graph_indices

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@nodes_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@edges_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@indices_table, [:set, :public, :named_table, read_concurrency: true])

    # Return state with table references
    {:ok, %{
      nodes_table: @nodes_table,
      edges_table: @edges_table,
      indices_table: @indices_table
    }}
  end

  @impl true
  def handle_call(:get_table_names, _from, state) do
    table_names = %{
      nodes: @nodes_table,
      edges: @edges_table,
      indices: @indices_table
    }

    {:reply, table_names, state}
  end

  # Public API

  @doc """
  Get the ETS table names.

  ## Examples

      iex> GraphOS.Graph.Storage.ETS.get_table_names()
      %{nodes: :graph_nodes, edges: :graph_edges, indices: :graph_indices}
  """
  def get_table_names do
    GenServer.call(__MODULE__, :get_table_names)
  end
end
