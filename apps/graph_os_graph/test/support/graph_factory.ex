defmodule GraphOS.Test.Support.GraphFactory do
  @moduledoc """
  Factory module to generate test data for graph-related tests.
  Provides functions to create vertices, edges, and graph structures.
  """

  alias GraphOS.Graph
  alias GraphOS.Graph.Edge
  alias GraphOS.Graph.Vertex

  @doc """
  Creates a new graph process with the specified number of vertices and edges.

  Returns the PID of the graph process.
  """
  def create_graph(vertex_count \\ 10, edge_count \\ 10, connection_type \\ :acyclic) do
    {:ok, graph_pid} = Graph.start_link(directed: false)
    graph_pid
    |> create_vertices(vertex_count)
    |> create_edges(edge_count, connection_type)
  end

  @doc """
  Adds the specified number of vertices to the graph process.

  Returns the graph process PID.
  """
  def create_vertices(graph_pid, count \\ 10) do
    Enum.each(1..count, fn i ->
      Graph.put_vertex(graph_pid, Vertex.new(%{}, id: "#{i}"))
    end)

    graph_pid
  end

  @doc """
  Creates a large cyclic graph for performance testing.

  Returns the PID of the graph process.
  """
  def create_large_cyclic_graph(vertex_count \\ 1000) do
    {:ok, graph_pid} = Graph.start_link(directed: false)

    # Create vertices
    vertices = Enum.map(1..vertex_count, fn i ->
      {:ok, vertex_id} = Graph.create_vertex(graph_pid, %{}, id: "#{i}")
      vertex_id
    end)

    # Create edges between consecutive vertices
    Enum.zip(vertices, Enum.drop(vertices, 1) ++ [List.first(vertices)])
    |> Enum.each(fn {source_id, target_id} ->
      Graph.create_edge(graph_pid, source_id, target_id)
    end)

    graph_pid
  end

  @doc """
  Adds edges to the graph according to the specified connection type.

  Returns the graph process PID.
  """
  def create_edges(graph_pid, edge_count, connection_type) do
    vertices = Graph.vertices(graph_pid)

    case connection_type do
      :acyclic -> create_acyclic_edges(graph_pid, vertices, edge_count)
      :cyclic -> create_cyclic_edges(graph_pid, vertices, edge_count)
      :random -> create_random_edges(graph_pid, vertices, edge_count)
    end

    graph_pid
  end

  @doc """
  Creates a cyclic pattern of edges in the graph.
  """
  def create_cyclic_edges(graph_pid, vertices, edge_count) do
    vertex_count = length(vertices)
    max_count = vertex_count - 1
    edge_count = min(edge_count, max_count)

    # Connect vertices in sequence
    1..edge_count
    |> Enum.each(fn i ->
      source = Enum.at(vertices, i - 1)
      target = Enum.at(vertices, i)
      Graph.create_edge(graph_pid, source.id, target.id)
    end)

    # Close the cycle by connecting the last vertex to the first
    Graph.create_edge(graph_pid, List.last(vertices).id, List.first(vertices).id)

    graph_pid
  end

  @doc """
  Creates an acyclic pattern of edges in the graph.
  """
  def create_acyclic_edges(graph_pid, vertices, edge_count) do
    vertex_count = length(vertices)
    max_count = vertex_count - 1
    edge_count = min(edge_count, max_count)

    # Connect vertices in sequence without creating a cycle
    1..edge_count
    |> Enum.each(fn i ->
      source = Enum.at(vertices, i - 1)
      target = Enum.at(vertices, i)
      Graph.create_edge(graph_pid, source.id, target.id)
    end)

    graph_pid
  end

  @doc """
  Creates random edges between vertices in the graph.
  """
  def create_random_edges(graph_pid, vertices, count) do
    Enum.each(1..count, fn _ ->
      source_id = Enum.random(vertices).id
      target_id = Enum.random(vertices).id
      # Ignore errors if we try to create duplicate edges
      Graph.create_edge_if_exists(graph_pid, source_id, target_id)
    end)

    graph_pid
  end

  @doc """
  Creates an edge between two vertices.
  """
  def create_edge(graph_pid, source_id, target_id) do
    Graph.create_edge(graph_pid, source_id, target_id)
    graph_pid
  end
end
