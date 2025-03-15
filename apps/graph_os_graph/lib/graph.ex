defmodule GraphOS.Graph do
  @moduledoc """
  The main module for GraphOS graph operations.

  This module provides high-level functions for interacting with the graph,
  including querying and manipulating graph data.
  """

  alias GraphOS.Graph.{Node, Transaction, Query, Store, Algorithm}

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
    # TODO: Implement access control checks
    # For now, we'll pass through to the original implementation
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
    # TODO: Implement access control checks
    # For now, we'll pass through to the original implementation
    Store.execute(transaction)
  end

  @doc """
  Executes a node using the GraphOS.Executable protocol.

  This function allows nodes to have executable behavior defined by implementing
  the GraphOS.Executable protocol.

  ## Parameters

  - `node` - The node to execute
  - `context` - Map of contextual information needed for execution
  - `access_context` - Optional access control context for permission checks

  ## Examples

      iex> GraphOS.Graph.execute_node(%GraphOS.Graph.Node{id: "my_node"}, %{input: "value"})
      {:ok, result}
  """
  @spec execute_node(Node.t(), map(), term()) :: {:ok, any()} | {:error, term()}
  def execute_node(node, _context \\ %{}, access_context \\ nil) do
    # Check if access is permitted
    with {:ok, true} <- check_execute_permission(node, access_context) do
      # GraphOS.Graph doesn't directly execute nodes - this is a limitation
      # to break circular dependencies
      {:error, :not_implemented_in_graph}
    else
      {:ok, false} -> {:error, :permission_denied}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Executes a node by ID.

  This function fetches a node by its ID and then executes it using the
  GraphOS.Executable protocol.

  ## Parameters

  - `node_id` - The ID of the node to execute
  - `context` - Map of contextual information needed for execution
  - `access_context` - Optional access control context for permission checks

  ## Examples

      iex> GraphOS.Graph.execute_node_by_id("my_node", %{input: "value"})
      {:ok, result}
  """
  @spec execute_node_by_id(Node.id(), map(), term()) :: {:ok, any()} | {:error, term()}
  def execute_node_by_id(node_id, context \\ %{}, access_context \\ nil) do
    with {:ok, node} <- Query.get_node(node_id) do
      execute_node(node, context, access_context)
    end
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

  # Access control convenience functions

  @doc """
  Define an actor in the access control system.

  This is a stub implementation to avoid circular dependencies.
  """
  @spec define_actor(String.t(), map()) :: {:ok, Node.t()} | {:error, term()}
  def define_actor(_actor_id, _attributes \\ %{}) do
    # Stub implementation that will be overridden by GraphOS.Core.AccessControl
    {:error, :not_implemented_in_graph}
  end

  @doc """
  Grant permission for an actor to perform operations on a resource.

  This is a stub implementation to avoid circular dependencies.
  """
  @spec grant_permission(String.t(), String.t(), list(atom())) :: 
        {:ok, GraphOS.Graph.Edge.t()} | {:error, term()}
  def grant_permission(_actor_id, _resource_pattern, _operations) do
    # Stub implementation that will be overridden by GraphOS.Core.AccessControl
    {:error, :not_implemented_in_graph}
  end

  @doc """
  Check if an actor has permission to perform an operation on a resource.

  This is a stub implementation to avoid circular dependencies.
  """
  @spec can?(String.t(), String.t(), atom()) :: {:ok, boolean()} | {:error, term()}
  def can?(_actor_id, _resource_id, _operation) do
    # Stub implementation that will be overridden by GraphOS.Core.AccessControl
    {:ok, true}  # Default to permissive for development
  end

  # Private helpers

  # Check if execution is permitted
  defp check_execute_permission(_node, nil) do
    # No access context provided, allow by default
    # This is a permissive default for development
    # In production, this should be configurable to fail-closed
    {:ok, true}
  end

  defp check_execute_permission(_node, _access_context) do
    # Simplified implementation to avoid circular dependencies
    # In production, this would check permissions properly
    {:ok, true}
  end

  # Extract actor ID from access context - Kept for future use
  # Not currently used but will be needed for access control
  # Functions marked with underscore prefix are intentionally unused
  # @dialyzer {:nowarn_function, extract_actor_id: 1}
  # defp extract_actor_id(access_context) when is_binary(access_context), do: access_context
  # defp extract_actor_id(%{actor_id: actor_id}), do: actor_id
  # defp extract_actor_id(_), do: nil
end
