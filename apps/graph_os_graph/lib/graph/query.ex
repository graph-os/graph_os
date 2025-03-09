defmodule GraphOS.Graph.Query do
  @moduledoc """
  A module for querying the graph.

  Provides functionality to traverse and filter graph data based on various criteria.
  """

  alias GraphOS.Graph.{Node, Edge, Store}

  @type query_params :: keyword() | map()
  @type query_result :: {:ok, list(Node.t() | Edge.t())} | {:error, term()}

  @doc """
  Execute a query against the graph.

  ## Parameters

  - `params`: A keyword list or map of query parameters

  ## Query Parameters

  - `:start_node_id` - The ID of the node to start the query from
  - `:edge_type` - Filter edges by type
  - `:direction` - Direction of edges, one of `:outgoing`, `:incoming`, or `:both` (default: `:outgoing`)
  - `:limit` - Maximum number of results to return (default: 100)
  - `:properties` - A map of property names to values to filter nodes/edges by
  - `:depth` - Maximum traversal depth (default: 1)

  ## Examples

      iex> Query.execute(start_node_id: "person1", edge_type: "knows")
      {:ok, [%Node{id: "person2", ...}, ...]}

      iex> Query.execute(%{start_node_id: "person1", depth: 2, properties: %{age: 30}})
      {:ok, [%Node{id: "person3", ...}, ...]}
  """
  @spec execute(query_params()) :: query_result()
  def execute(params) when is_list(params) or is_map(params) do
    # Convert keyword list to map if needed
    params = if is_list(params), do: Map.new(params), else: params

    # Apply default parameters
    params = Map.merge(
      %{
        direction: :outgoing,
        limit: 100,
        depth: 1
      },
      params
    )

    # Validate required parameters
    with {:ok, params} <- validate_params(params),
         {:ok, store} <- get_store() do
      # Execute the query through the store's query mechanism
      store.query(params)
    end
  end

  @doc """
  Get a node by ID.

  ## Examples

      iex> Query.get_node("person1")
      {:ok, %Node{id: "person1", ...}}
  """
  @spec get_node(Node.id()) :: {:ok, Node.t()} | {:error, term()}
  def get_node(node_id) do
    with {:ok, store} <- get_store() do
      store.get_node(node_id)
    end
  end

  @doc """
  Get an edge by ID.

  ## Examples

      iex> Query.get_edge("edge1")
      {:ok, %Edge{id: "edge1", ...}}
  """
  @spec get_edge(Edge.id()) :: {:ok, Edge.t()} | {:error, term()}
  def get_edge(edge_id) do
    with {:ok, store} <- get_store() do
      store.get_edge(edge_id)
    end
  end

  @doc """
  Find nodes by property values.

  ## Examples

      iex> Query.find_nodes_by_properties(%{name: "John", age: 30})
      {:ok, [%Node{id: "person1", properties: %{name: "John", age: 30, ...}}, ...]}
  """
  @spec find_nodes_by_properties(map()) :: {:ok, list(Node.t())} | {:error, term()}
  def find_nodes_by_properties(properties) when is_map(properties) do
    with {:ok, store} <- get_store() do
      store.find_nodes_by_properties(properties)
    end
  end

  # Private functions

  defp validate_params(params) do
    cond do
      !Map.has_key?(params, :start_node_id) ->
        {:error, "Missing required parameter: start_node_id"}

      # Add more validations as needed

      true ->
        {:ok, params}
    end
  end

  defp get_store do
    # For now, we'll default to the ETS store
    # This could be enhanced to dynamically select a store based on configuration
    {:ok, GraphOS.Graph.Store.ETS}
  end
end
