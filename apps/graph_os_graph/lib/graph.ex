defmodule GraphOS.Graph do
  @moduledoc """
  The main module for GraphOS graph operations.

  This module provides high-level functions for interacting with the graph,
  including querying and manipulating graph data.
  """
  
  use Boundary, exports: [], deps: [:mcp]

  alias GraphOS.Graph.{Node, Transaction, Query, Store, Algorithm, Subscription}

  @doc """
  Initialize the graph store.

  ## Parameters

  - `opts` - Initialization options
    - `:store_module` - The storage module to use (default: GraphOS.Graph.Store.ETS)
    - `:access_control` - Whether to initialize access control (default: true)
    - `:name` - Name for the graph (default: "default")

  ## Examples

      iex> GraphOS.Graph.init()
      :ok

      iex> GraphOS.Graph.init(access_control: false)
      :ok
  """
  @spec init(keyword()) :: :ok | {:error, term()}
  def init(opts \\ []) do
    store_module = Keyword.get(opts, :store_module, GraphOS.Graph.Store.ETS)
    _enable_access_control = Keyword.get(opts, :access_control, true)

    # Initialize the store
    case Store.init(store_module) do
      {:ok, _config} ->
        # Don't immediately initialize access control here,
        # this will avoid circular dependencies
        :ok
      :ok ->
        # Handle legacy return value
        :ok
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Query the graph using the query engine.

  ## Parameters

  - `query_params` - Query parameters
  - `access_context` - Optional access control context

  ## Examples

      iex> GraphOS.Graph.query(start_node_id: "person1", edge_type: "knows")
      {:ok, [%Node{id: "person2", ...}, ...]}
  """
  @spec query(Query.query_params(), term()) :: Query.query_result()
  def query(query_params, _access_context \\ nil) do
    Query.execute(query_params)
  end

  @doc """
  Executes a transaction against the graph.

  ## Parameters

  - `transaction` - The transaction to execute
  - `access_context` - Optional access control context

  ## Examples

      iex> transaction = %Transaction{...}
      iex> GraphOS.Graph.execute(transaction)
      {:ok, result}
  """
  @spec execute(Transaction.t(), term()) :: {:ok, term()} | {:error, term()}
  def execute(transaction, _access_context \\ nil) do
    Store.execute(transaction)
  end


  # Algorithm-related functions

  @doc """
  Performs a breadth-first search (BFS) starting from the specified node.

  ## Examples

      iex> GraphOS.Graph.bfs("person1")
      {:ok, [%Node{id: "person1"}, %Node{id: "person2"}, ...]}
  """
  @spec bfs(Node.id(), Algorithm.algorithm_opts()) :: Algorithm.traversal_result()
  def bfs(start_node_id, opts \\ []) do
    Algorithm.bfs(start_node_id, opts)
  end

  @doc """
  Finds the shortest path between two nodes.

  ## Examples

      iex> GraphOS.Graph.shortest_path("person1", "person5")
      {:ok, [%Node{id: "person1"}, %Node{id: "person3"}, %Node{id: "person5"}], 7.5}
  """
  @spec shortest_path(Node.id(), Node.id(), Algorithm.algorithm_opts()) :: Algorithm.path_result()
  def shortest_path(source_node_id, target_node_id, opts \\ []) do
    Algorithm.shortest_path(source_node_id, target_node_id, opts)
  end

  @doc """
  Finds all connected components in the graph.

  ## Examples

      iex> GraphOS.Graph.connected_components()
      {:ok, [[%Node{id: "person1"}, %Node{id: "person2"}], [%Node{id: "person3"}]]}
  """
  @spec connected_components(Algorithm.algorithm_opts()) :: Algorithm.components_result()
  def connected_components(opts \\ []) do
    Algorithm.connected_components(opts)
  end

  @doc """
  Calculates PageRank values for all nodes in the graph.

  ## Examples

      iex> GraphOS.Graph.pagerank()
      {:ok, %{"node1" => 0.25, "node2" => 0.15, ...}}
  """
  @spec pagerank(Algorithm.algorithm_opts()) :: Algorithm.pagerank_result()
  def pagerank(opts \\ []) do
    Algorithm.pagerank(opts)
  end

  @doc """
  Finds the minimum spanning tree of the graph.

  ## Examples

      iex> GraphOS.Graph.minimum_spanning_tree()
      {:ok, [%Edge{...}, ...], 42.5}
  """
  @spec minimum_spanning_tree(Algorithm.algorithm_opts()) :: Algorithm.mst_result()
  def minimum_spanning_tree(opts \\ []) do
    Algorithm.minimum_spanning_tree(opts)
  end
  
  # Subscription functions
  
  @doc """
  Subscribe to events for a specific node.
  
  This is a convenience function that uses the configured subscription module.
  The default implementation is a no-op that does nothing.
  
  ## Parameters
  
  - `node_id` - The ID of the node to subscribe to
  - `opts` - Subscription options
  
  ## Examples
  
      iex> GraphOS.Graph.subscribe_to_node("node1")
      {:ok, #Reference<0.123.456.789>}
  """
  @spec subscribe_to_node(Node.id(), keyword()) :: 
        {:ok, Subscription.subscription_id()} | {:error, term()}
  def subscribe_to_node(node_id, opts \\ []) do
    subscription_module().subscribe("node:#{node_id}", opts)
  end
  
  @doc """
  Subscribe to events for a specific edge.
  
  This is a convenience function that uses the configured subscription module.
  The default implementation is a no-op that does nothing.
  
  ## Parameters
  
  - `edge_id` - The ID of the edge to subscribe to
  - `opts` - Subscription options
  
  ## Examples
  
      iex> GraphOS.Graph.subscribe_to_edge("edge1")
      {:ok, #Reference<0.123.456.789>}
  """
  @spec subscribe_to_edge(Edge.id(), keyword()) :: 
        {:ok, Subscription.subscription_id()} | {:error, term()}
  def subscribe_to_edge(edge_id, opts \\ []) do
    subscription_module().subscribe("edge:#{edge_id}", opts)
  end
  
  @doc """
  Subscribe to events for the entire graph.
  
  This is a convenience function that uses the configured subscription module.
  The default implementation is a no-op that does nothing.
  
  ## Parameters
  
  - `opts` - Subscription options
  
  ## Examples
  
      iex> GraphOS.Graph.subscribe_to_graph()
      {:ok, #Reference<0.123.456.789>}
  """
  @spec subscribe_to_graph(keyword()) :: 
        {:ok, Subscription.subscription_id()} | {:error, term()}
  def subscribe_to_graph(opts \\ []) do
    subscription_module().subscribe("graph", opts)
  end
  
  @doc """
  Unsubscribe from events.
  
  This is a convenience function that uses the configured subscription module.
  The default implementation is a no-op that does nothing.
  
  ## Parameters
  
  - `subscription_id` - The ID returned from a subscribe function
  
  ## Examples
  
      iex> {:ok, id} = GraphOS.Graph.subscribe_to_node("node1")
      iex> GraphOS.Graph.unsubscribe(id)
      :ok
  """
  @spec unsubscribe(Subscription.subscription_id()) :: :ok | {:error, term()}
  def unsubscribe(subscription_id) do
    subscription_module().unsubscribe(subscription_id)
  end
  
  # Return the configured subscription module or the default
  defp subscription_module do
    Application.get_env(:graph_os_graph, :subscription_module, 
                         GraphOS.Graph.Subscription.NoOp)
  end
end
