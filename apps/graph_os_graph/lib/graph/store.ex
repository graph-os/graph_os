defmodule GraphOS.GraphContext.Store do
  @moduledoc """
  Context for `GraphOS.GraphContext` stores.

  ## Storage drivers

  - `GraphOS.GraphContext.Store.ETS` - An ETS-based store.

  ## Access Control

  The store supports access control through the `GraphOS.GraphContext.Access` behaviour.
  Pass an access control module to store operations to enforce permissions:

  ```elixir
  # Initialize with access control
  GraphOS.GraphContext.Store.init(GraphOS.GraphContext.Store.ETS, 
    access_control: MyAccessControl,
    access_context: %{actor_id: "user:alice", graph: graph}
  )

  # Query with access control
  GraphOS.GraphContext.Store.query(params, GraphOS.GraphContext.Store.ETS,
    access_control: MyAccessControl,
    access_context: %{actor_id: "user:alice", graph: graph}
  )
  ```
  """
  
  use Boundary, deps: []

  alias GraphOS.GraphContext.{Transaction, Operation, Node, Edge, Query}

  @type t() :: module()
  @type access_control_module :: module() | nil
  @type access_context :: map() | nil

  @doc """
  Initialize the store.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions
  - Other options are passed to the store implementation

  ## Examples

      iex> GraphOS.GraphContext.Store.init(GraphOS.GraphContext.Store.ETS)
      {:ok, %{table: :graph_os_ets_store}}
      
      iex> GraphOS.GraphContext.Store.init(GraphOS.GraphContext.Store.ETS, access_control: MyAccessControl)
      {:ok, %{table: :graph_os_ets_store}}
  """
  @spec init(module(), keyword()) :: {:ok, term()} | {:error, term()}
  def init(module \\ GraphOS.GraphContext.Store.ETS, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    _access_context = Keyword.get(opts, :access_context)
    
    # Initialize access control if provided
    result = if access_module do
      access_module.init(Keyword.merge(opts, [graph: self()]))
    else
      :ok
    end
    
    case result do
      :ok ->
        # Try to call init with options first (Core implementation)
        try do
          module.init(opts)
        rescue
          # If that fails with an UndefinedFunctionError, try legacy protocol style
          err in UndefinedFunctionError ->
            if err.function == :init and err.arity == 1 do
              # Legacy protocol implementation doesn't take options
              module.init()
            else
              # Reraise if it's a different error
              reraise err, __STACKTRACE__
            end
        end
      error ->
        error
    end
  end

  @doc """
  Execute a transaction.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions

  ## Examples

      iex> GraphOS.GraphContext.Store.execute(transaction)
      {:ok, %{results: [...]}}
      
      iex> GraphOS.GraphContext.Store.execute(transaction, access_control: MyAccessControl, access_context: %{actor_id: "user1"})
      {:ok, %{results: [...]}}
  """
  @spec execute(Transaction.t(), keyword()) :: Transaction.result()
  def execute(transaction, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    
    # If access control is enabled, authorize all operations in the transaction
    if access_module do
      # Check each operation in the transaction
      result = Enum.reduce_while(transaction.operations, {:ok, []}, fn op, {:ok, authorized_ops} ->
        case access_module.authorize_operation(op, access_context) do
          {:ok, true} -> 
            {:cont, {:ok, [op | authorized_ops]}}
          {:ok, false} -> 
            {:halt, {:error, {:unauthorized, op}}}
          error -> 
            {:halt, error}
        end
      end)
      
      case result do
        {:ok, _} ->
          # All operations authorized, proceed with execution
          transaction.store.execute(transaction)
        error ->
          error
      end
    else
      # No access control, execute directly
      transaction.store.execute(transaction)
    end
  end

  @doc """
  Rollback a transaction.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions
  """
  @spec rollback(Transaction.t(), keyword()) :: :ok | {:error, term()}
  def rollback(transaction, opts \\ []) do
    _access_module = Keyword.get(opts, :access_control)
    _access_context = Keyword.get(opts, :access_context, %{})
    
    # For rollbacks, we generally allow them if the transaction was authorized initially
    # but we could add additional access checks here if needed
    transaction.store.rollback(transaction)
  end

  @doc """
  Handle an operation.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions
  """
  @spec handle(Operation.message(), keyword()) :: :ok | {:error, term()}
  def handle(operation, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    store_module = Keyword.get(opts, :store, GraphOS.GraphContext.Store.ETS)
    
    # Convert to structured operation if it's a message tuple
    op = if is_tuple(operation), do: Operation.from_message(operation), else: operation
    
    # Authorize operation if access control is enabled
    if access_module do
      case access_module.authorize_operation(op, access_context) do
        {:ok, true} -> 
          # Operation authorized, proceed
          store_module.handle(operation)
        {:ok, false} -> 
          {:error, :unauthorized}
        error -> 
          error
      end
    else
      # No access control, handle directly
      store_module.handle(operation)
    end
  end

  @doc """
  Close the store.
  """
  @spec close(module(), keyword()) :: :ok | {:error, term()}
  def close(module \\ GraphOS.GraphContext.Store.ETS, _opts \\ []) do
    module.close()
  end

  # Query-related functions

  @doc """
  Execute a query against the store.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions

  ## Examples

      iex> GraphOS.GraphContext.Store.query(params, GraphOS.GraphContext.Store.ETS)
      {:ok, [%Node{}, ...]}
      
      iex> GraphOS.GraphContext.Store.query(params, GraphOS.GraphContext.Store.ETS, access_control: MyAccessControl)
      {:ok, [%Node{}, ...]}
  """
  @spec query(Query.query_params(), module(), keyword()) :: Query.query_result()
  def query(params, module \\ GraphOS.GraphContext.Store.ETS, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    
    # Execute query
    result = module.query(params)
    
    # If access control is enabled, filter the results
    case result do
      {:ok, nodes} when is_list(nodes) and access_module != nil ->
        access_module.filter_authorized_nodes(nodes, :read, access_context)
      {:ok, %{nodes: nodes, edges: edges}} when access_module != nil ->
        with {:ok, filtered_nodes} <- access_module.filter_authorized_nodes(nodes, :read, access_context),
             {:ok, filtered_edges} <- access_module.filter_authorized_edges(edges, :read, access_context) do
          {:ok, %{nodes: filtered_nodes, edges: filtered_edges}}
        end
      _ ->
        result
    end
  end

  @doc """
  Get a node by ID.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions

  ## Examples

      iex> GraphOS.GraphContext.Store.get_node("node1", GraphOS.GraphContext.Store.ETS)
      {:ok, %Node{id: "node1", ...}}
  """
  @spec get_node(Node.id(), module(), keyword()) :: {:ok, Node.t()} | {:error, term()}
  def get_node(node_id, module \\ GraphOS.GraphContext.Store.ETS, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    
    # Get the node
    result = module.get_node(node_id)
    
    # Check access if module is provided
    case result do
      {:ok, node} when access_module != nil ->
        case access_module.authorize(node_id, :read, access_context) do
          {:ok, true} -> {:ok, node}
          {:ok, false} -> {:error, :unauthorized}
          error -> error
        end
      _ ->
        result
    end
  end

  @doc """
  Get an edge by ID.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions

  ## Examples

      iex> GraphOS.GraphContext.Store.get_edge("edge1", GraphOS.GraphContext.Store.ETS)
      {:ok, %Edge{id: "edge1", ...}}
  """
  @spec get_edge(Edge.id(), module(), keyword()) :: {:ok, Edge.t()} | {:error, term()}
  def get_edge(edge_id, module \\ GraphOS.GraphContext.Store.ETS, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    
    # Get the edge
    result = module.get_edge(edge_id)
    
    # Check access if module is provided
    case result do
      {:ok, edge} when access_module != nil ->
        case access_module.authorize_edge(edge_id, :read, access_context) do
          {:ok, true} -> {:ok, edge}
          {:ok, false} -> {:error, :unauthorized}
          error -> error
        end
      _ ->
        result
    end
  end

  @doc """
  Find nodes by property values.

  ## Options

  - `access_control` - Module implementing the `GraphOS.GraphContext.Access` behaviour
  - `access_context` - Map with context for access control decisions

  ## Examples

      iex> GraphOS.GraphContext.Store.find_nodes_by_properties(%{name: "John"}, GraphOS.GraphContext.Store.ETS)
      {:ok, [%Node{...}, ...]}
  """
  @spec find_nodes_by_properties(map(), module(), keyword()) :: {:ok, list(Node.t())} | {:error, term()}
  def find_nodes_by_properties(properties, module \\ GraphOS.GraphContext.Store.ETS, opts \\ []) do
    access_module = Keyword.get(opts, :access_control)
    access_context = Keyword.get(opts, :access_context, %{})
    
    # Find nodes
    result = module.find_nodes_by_properties(properties)
    
    # Filter by access control if enabled
    case result do
      {:ok, nodes} when is_list(nodes) and access_module != nil ->
        access_module.filter_authorized_nodes(nodes, :read, access_context)
      _ ->
        result
    end
  end
  
  @doc """
  Get the current store module.
  
  ## Returns
  
  - `module()` - The current store module
  """
  @spec get_store_module() :: module()
  def get_store_module do
    # In a real implementation, this would be configurable or determined from context
    # For now, we'll just use ETS as the default store
    GraphOS.GraphContext.Store.ETS
  end
  
  @doc """
  Create a new access control context.
  
  ## Parameters
  
  - `opts` - Options for the access control context
    - `:actor_id` - The actor ID for access control decisions
    - `:graph` - The graph reference
  
  ## Returns
  
  - `map()` - Access control context
  """
  @spec create_access_context(keyword()) :: map()
  def create_access_context(opts \\ []) do
    %{
      actor_id: Keyword.get(opts, :actor_id),
      graph: Keyword.get(opts, :graph)
    }
  end
end
