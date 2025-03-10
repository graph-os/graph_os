defmodule GraphOS.Test.Support.GraphFactory do
  @moduledoc """
  Factory module to generate test data for graph-related tests.
  Provides functions to create nodes, edges, and graph structures.
  """

  alias GraphOS.Graph
  alias GraphOS.Graph.Edge
  alias GraphOS.Graph.Node
  alias GraphOS.Graph.Transaction

  @doc """
  Initializes the graph store and creates a graph with the specified number of nodes and edges.

  Returns :ok when successful.
  """
  def create_graph(node_count \\ 10, edge_count \\ 10, connection_type \\ :acyclic) do
    Graph.init()
    create_nodes(node_count)
    create_edges(node_count, edge_count, connection_type)
    :ok
  end

  @doc """
  Adds the specified number of nodes to the graph.

  Returns a list of the created node IDs.
  """
  def create_nodes(count \\ 10) do
    Enum.map(1..count, fn i ->
      node_id = "#{i}"
      node = Node.new(%{}, id: node_id)

      {:ok, _} = Graph.execute(%Transaction{
        operations: [
          {:create_node, node}
        ]
      })

      node_id
    end)
  end

  @doc """
  Creates a large cyclic graph for performance testing.

  Returns :ok when successful.
  """
  def create_large_cyclic_graph(node_count \\ 1000) do
    Graph.init()

    # Create nodes
    node_ids = create_nodes(node_count)

    # Create edges between consecutive nodes
    Enum.zip(node_ids, Enum.drop(node_ids, 1) ++ [List.first(node_ids)])
    |> Enum.each(fn {source_id, target_id} ->
      create_edge(source_id, target_id)
    end)

    :ok
  end

  @doc """
  Adds edges to the graph according to the specified connection type.

  Returns :ok when successful.
  """
  def create_edges(node_count, edge_count, connection_type) do
    node_ids = Enum.map(1..node_count, fn i -> "#{i}" end)

    case connection_type do
      :acyclic -> create_acyclic_edges(node_ids, edge_count)
      :cyclic -> create_cyclic_edges(node_ids, edge_count)
      :random -> create_random_edges(node_ids, edge_count)
    end

    :ok
  end

  @doc """
  Creates a cyclic pattern of edges in the graph.
  """
  def create_cyclic_edges(node_ids, edge_count) do
    node_count = length(node_ids)
    max_count = node_count - 1
    edge_count = min(edge_count, max_count)

    # Connect nodes in sequence
    1..edge_count
    |> Enum.each(fn i ->
      source = Enum.at(node_ids, i - 1)
      target = Enum.at(node_ids, i)
      create_edge(source, target)
    end)

    # Close the cycle by connecting the last node to the first
    create_edge(List.last(node_ids), List.first(node_ids))

    :ok
  end

  @doc """
  Creates an acyclic pattern of edges in the graph.
  """
  def create_acyclic_edges(node_ids, edge_count) do
    node_count = length(node_ids)
    max_count = node_count - 1
    edge_count = min(edge_count, max_count)

    # Connect nodes in sequence without creating a cycle
    1..edge_count
    |> Enum.each(fn i ->
      source = Enum.at(node_ids, i - 1)
      target = Enum.at(node_ids, i)
      create_edge(source, target)
    end)

    :ok
  end

  @doc """
  Creates random edges between nodes in the graph.
  """
  def create_random_edges(node_ids, count) do
    Enum.each(1..count, fn _ ->
      source_id = Enum.random(node_ids)
      target_id = Enum.random(node_ids)

      # Only create edge if source and target are different
      if source_id != target_id do
        create_edge(source_id, target_id)
      end
    end)

    :ok
  end

  @doc """
  Creates an edge between two nodes.
  """
  def create_edge(source_id, target_id) do
    edge = Edge.new(source_id, target_id)

    {:ok, _} = Graph.execute(%Transaction{
      operations: [
        {:create_edge, edge}
      ]
    })

    :ok
  end
end
