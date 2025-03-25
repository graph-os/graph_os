defmodule GraphOS.Store.Algorithm.ConnectedComponents do
  @moduledoc """
  Implementation of Connected Components algorithm.
  """

  alias GraphOS.Entity.{Node, Edge}
  alias GraphOS.Store
  alias GraphOS.Store.Algorithm.Utils.DisjointSet

  @doc """
  Execute a connected components analysis on the graph.

  ## Parameters

  - `opts` - Options for the connected components algorithm

  ## Returns

  - `{:ok, list(list(Node.t()))}` - List of connected components (each component is a list of nodes)
  - `{:error, reason}` - Error with reason
  """
  @spec execute(Keyword.t()) :: {:ok, list(list(Node.t()))} | {:error, term()}
  def execute(opts) do
    # Get all nodes in the graph
    case Store.all(Node, %{}) do
      {:ok, nodes} ->
        # Extract options
        edge_type = Keyword.get(opts, :edge_type)
        direction = Keyword.get(opts, :direction, :both)

        # Get node IDs
        node_ids = Enum.map(nodes, & &1.id)

        # Initialize disjoint set
        disjoint_set = DisjointSet.new(node_ids)

        # Get all edges
        edge_filter = if edge_type, do: %{type: edge_type}, else: %{}

        case Store.all(Edge, edge_filter) do
          {:ok, edges} ->
            # For each edge, union the connected nodes
            final_set = process_edges(edges, disjoint_set, direction)

            # Extract the connected components
            components_map = DisjointSet.get_sets(final_set)

            # Convert the sets to lists of nodes
            components =
              components_map
              |> Map.values()
              |> Enum.map(fn component_ids ->
                # Convert IDs to nodes
                Enum.map(component_ids, fn id ->
                  {:ok, node} = Store.get(Node, id)
                  node
                end)
              end)
              |> Enum.reject(&Enum.empty?/1)

            {:ok, components}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_edges(edges, disjoint_set, direction) do
    Enum.reduce(edges, disjoint_set, fn edge, set ->
      case direction do
        :outgoing -> DisjointSet.union(set, edge.source, edge.target)
        :incoming -> DisjointSet.union(set, edge.target, edge.source)
        :both -> DisjointSet.union(set, edge.source, edge.target)
      end
    end)
  end
end
