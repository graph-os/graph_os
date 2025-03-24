defmodule GraphOS.Store.Query do
  @moduledoc """
  Defines a query for GraphOS.Store.

  A query represents a read operation to retrieve data from the store.
  """

  @type operation_type ::
          :get
          | :list
          | :search
          | :traverse
          | :shortest_path
          | :connected_components
          | :pagerank
          | :minimum_spanning_tree
  @type entity_type :: :graph | :node | :edge
  @type t :: %__MODULE__{
          operation: operation_type(),
          entity: entity_type(),
          start_node_id: String.t() | nil,
          target_node_id: String.t() | nil,
          id: String.t() | nil,
          filter: map() | nil,
          opts: Keyword.t()
        }

  defstruct operation: nil,
            entity: nil,
            start_node_id: nil,
            target_node_id: nil,
            id: nil,
            filter: nil,
            opts: []

  @doc """
  Creates a new query for retrieving a single entity by ID.

  ## Parameters

  - `entity` - The type of entity (:graph, :node, :edge)
  - `id` - The ID of the entity to retrieve
  - `opts` - Additional options for the query

  ## Examples

      iex> GraphOS.Store.Query.get(:node, "node1")
      %GraphOS.Store.Query{operation: :get, entity: :node, id: "node1", opts: []}
  """
  @spec get(entity_type(), String.t(), Keyword.t()) :: t()
  def get(entity, id, opts \\ []) when entity in [:graph, :node, :edge] and is_binary(id) do
    %__MODULE__{
      operation: :get,
      entity: entity,
      id: id,
      opts: opts
    }
  end

  @doc """
  Creates a new query for listing entities with optional filtering.

  ## Parameters

  - `entity` - The type of entity (:graph, :node, :edge)
  - `filter` - Map of property names to values for filtering
  - `opts` - Additional options for the query

  ## Examples

      iex> GraphOS.Store.Query.list(:node, %{type: "person"})
      %GraphOS.Store.Query{operation: :list, entity: :node, filter: %{type: "person"}, opts: []}
  """
  @spec list(entity_type(), map(), Keyword.t()) :: t()
  def list(entity, filter \\ %{}, opts \\ []) when entity in [:graph, :node, :edge] do
    %__MODULE__{
      operation: :list,
      entity: entity,
      filter: filter,
      opts: opts
    }
  end

  @doc """
  Creates a new query for traversing the graph starting from a node.

  ## Parameters

  - `start_node_id` - The ID of the node to start the traversal from
  - `opts` - Options for the traversal, such as:
    - `:algorithm` - Algorithm to use (:bfs, :dfs)
    - `:max_depth` - Maximum traversal depth
    - `:edge_type` - Filter edges by type
    - `:direction` - Direction of traversal (:outgoing, :incoming, :both)

  ## Examples

      iex> GraphOS.Store.Query.traverse("node1", algorithm: :bfs, max_depth: 3)
      %GraphOS.Store.Query{operation: :traverse, start_node_id: "node1", opts: [algorithm: :bfs, max_depth: 3]}
  """
  @spec traverse(String.t(), Keyword.t()) :: t()
  def traverse(start_node_id, opts \\ []) when is_binary(start_node_id) do
    %__MODULE__{
      operation: :traverse,
      entity: :node,
      start_node_id: start_node_id,
      opts: opts
    }
  end

  @doc """
  Creates a new query for finding the shortest path between two nodes.

  ## Parameters

  - `start_node_id` - The ID of the source node
  - `target_node_id` - The ID of the target node
  - `opts` - Options for the shortest path algorithm, such as:
    - `:edge_type` - Filter edges by type
    - `:weight_property` - Property name to use for edge weights

  ## Examples

      iex> GraphOS.Store.Query.shortest_path("node1", "node5", weight_property: "distance")
      %GraphOS.Store.Query{operation: :shortest_path, start_node_id: "node1", target_node_id: "node5", opts: [weight_property: "distance"]}
  """
  @spec shortest_path(String.t(), String.t(), Keyword.t()) :: t()
  def shortest_path(start_node_id, target_node_id, opts \\ [])
      when is_binary(start_node_id) and is_binary(target_node_id) do
    %__MODULE__{
      operation: :shortest_path,
      entity: :node,
      start_node_id: start_node_id,
      target_node_id: target_node_id,
      opts: opts
    }
  end

  @doc """
  Creates a new query for finding connected components in the graph.

  ## Parameters

  - `opts` - Options for the connected components algorithm, such as:
    - `:edge_type` - Filter edges by type
    - `:direction` - Direction for component analysis (:outgoing, :incoming, :both)

  ## Examples

      iex> GraphOS.Store.Query.connected_components(edge_type: "friend")
      %GraphOS.Store.Query{operation: :connected_components, opts: [edge_type: "friend"]}
  """
  @spec connected_components(Keyword.t()) :: t()
  def connected_components(opts \\ []) do
    %__MODULE__{
      operation: :connected_components,
      entity: :node,
      opts: opts
    }
  end

  @doc """
  Creates a new query for running the PageRank algorithm on the graph.

  ## Parameters

  - `opts` - Options for the PageRank algorithm, such as:
    - `:iterations` - Number of iterations to run
    - `:damping` - Damping factor
    - `:weighted` - Whether to consider edge weights

  ## Examples

      iex> GraphOS.Store.Query.pagerank(iterations: 30, damping: 0.9)
      %GraphOS.Store.Query{operation: :pagerank, opts: [iterations: 30, damping: 0.9]}
  """
  @spec pagerank(Keyword.t()) :: t()
  def pagerank(opts \\ []) do
    %__MODULE__{
      operation: :pagerank,
      entity: :node,
      opts: opts
    }
  end

  @doc """
  Creates a new query for finding the minimum spanning tree of the graph.

  ## Parameters

  - `opts` - Options for the minimum spanning tree algorithm, such as:
    - `:edge_type` - Filter edges by type
    - `:weight_property` - Property name to use for edge weights

  ## Examples

      iex> GraphOS.Store.Query.minimum_spanning_tree(weight_property: "distance")
      %GraphOS.Store.Query{operation: :minimum_spanning_tree, opts: [weight_property: "distance"]}
  """
  @spec minimum_spanning_tree(Keyword.t()) :: t()
  def minimum_spanning_tree(opts \\ []) do
    %__MODULE__{
      operation: :minimum_spanning_tree,
      opts: opts
    }
  end

  @doc """
  Creates a query for finding nodes by their properties.

  ## Parameters

  - `properties` - Map of property names to values for filtering nodes

  ## Examples

      iex> GraphOS.Store.Query.find_nodes_by_properties(%{type: "person"})
      %GraphOS.Store.Query{operation: :list, entity: :node, filter: %{type: "person"}, opts: []}
  """
  @spec find_nodes_by_properties(map()) :: t()
  def find_nodes_by_properties(properties) do
    list(:node, properties)
  end

  @doc """
  Validates the query.

  ## Examples

      iex> query = GraphOS.Store.Query.get(:node, "node1")
      iex> GraphOS.Store.Query.validate(query)
      :ok

      iex> query = %GraphOS.Store.Query{operation: :get, entity: :node}
      iex> GraphOS.Store.Query.validate(query)
      {:error, "Missing required parameter: id for get operation"}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = query) do
    case query.operation do
      :get when is_nil(query.id) ->
        {:error, "Missing required parameter: id for get operation"}

      :traverse when is_nil(query.start_node_id) ->
        {:error, "Missing required parameter: start_node_id for traverse operation"}

      :shortest_path when is_nil(query.start_node_id) or is_nil(query.target_node_id) ->
        {:error,
         "Missing required parameters: start_node_id or target_node_id for shortest_path operation"}

      _ ->
        :ok
    end
  end
end
