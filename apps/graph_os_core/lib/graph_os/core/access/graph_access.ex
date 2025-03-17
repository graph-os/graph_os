defmodule GraphOS.Core.Access.GraphAccess do
  @moduledoc """
  Implementation of the GraphOS.Graph.Access behaviour.

  This module provides an implementation of the access control interface defined
  in GraphOS.Graph.Access, using the GraphOS.Core.AccessControl system.
  
  It serves as the bridge between the GraphOS.Graph access control interface
  and the Core access control implementation, handling authorization of operations,
  filtering results, and providing access checks.
  """

  @behaviour GraphOS.Graph.Access

  alias GraphOS.Core.AccessControl
  alias GraphOS.Graph.Operation

  @doc """
  Initialize the access control system.

  ## Parameters

  - `opts` - Options for initialization
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `:ok` - Successfully initialized
  - `{:error, reason}` - Error occurred during initialization
  """
  @impl true
  def init(opts) do
    graph = Keyword.get(opts, :graph)

    if graph do
      AccessControl.init(graph)
    else
      {:error, :missing_graph}
    end
  end

  @doc """
  Authorize an operation on a node.

  ## Parameters

  - `node_id` - The ID of the node to authorize access to
  - `operation` - The operation type (:read, :write, :execute, :admin)
  - `context` - Additional context for the authorization decision
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `{:ok, true}` - Operation is authorized
  - `{:ok, false}` - Operation is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  def authorize(node_id, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      AccessControl.can?(graph, actor_id, node_id, operation)
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Authorize an operation on an edge.

  ## Parameters

  - `edge_id` - The ID of the edge to authorize access to
  - `operation` - The operation type (:read, :write, :execute, :admin)
  - `context` - Additional context for the authorization decision
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `{:ok, true}` - Operation is authorized
  - `{:ok, false}` - Operation is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  def authorize_edge(edge_id, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      AccessControl.can?(graph, actor_id, edge_id, operation)
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Authorize a graph operation before it is executed.

  ## Parameters

  - `operation` - The operation to authorize
  - `context` - Additional context for the authorization decision
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `{:ok, true}` - Operation is authorized
  - `{:ok, false}` - Operation is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  @impl true
  def authorize_operation(%Operation{} = operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      case operation do
        %{action: :create, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          AccessControl.can?(graph, actor_id, node_id, :write)

        %{action: :update, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          AccessControl.can?(graph, actor_id, node_id, :write)

        %{action: :delete, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          AccessControl.can?(graph, actor_id, node_id, :write)

        %{action: :create, entity: :edge, opts: opts} ->
          source = Keyword.get(opts, :source)
          target = Keyword.get(opts, :target)

          with {:ok, source_auth} <- AccessControl.can?(graph, actor_id, source, :write),
               {:ok, target_auth} <- AccessControl.can?(graph, actor_id, target, :read) do
            {:ok, source_auth && target_auth}
          end

        %{action: :update, entity: :edge, opts: opts} ->
          edge_id = Keyword.get(opts, :id)
          AccessControl.can?(graph, actor_id, edge_id, :write)

        %{action: :delete, entity: :edge, opts: opts} ->
          edge_id = Keyword.get(opts, :id)
          AccessControl.can?(graph, actor_id, edge_id, :write)

        _ ->
          # Default deny for unknown operations
          {:ok, false}
      end
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Filter a list of nodes based on access permissions.

  ## Parameters

  - `nodes` - The list of nodes to filter
  - `operation` - The operation type (:read, :write, :execute, :admin)
  - `context` - Additional context for the authorization decision
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `{:ok, filtered_nodes}` - Filtered list of nodes
  - `{:error, reason}` - Error occurred during filtering
  """
  def filter_authorized_nodes(nodes, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      # Filter nodes based on authorization
      results =
        Enum.reduce_while(nodes, {[], []}, fn node, {authorized, errors} ->
          case AccessControl.can?(graph, actor_id, node.id, operation) do
            {:ok, true} -> {:cont, {[node | authorized], errors}}
            {:ok, false} -> {:cont, {authorized, errors}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case results do
        {authorized, _} when is_list(authorized) ->
          {:ok, Enum.reverse(authorized)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Filter a list of edges based on access permissions.

  ## Parameters

  - `edges` - The list of edges to filter
  - `operation` - The operation type (:read, :write, :execute, :admin)
  - `context` - Additional context for the authorization decision
    - `:actor_id` - The current actor ID (required)
    - `:graph` - The graph instance (required)

  ## Returns

  - `{:ok, filtered_edges}` - Filtered list of edges
  - `{:error, reason}` - Error occurred during filtering
  """
  def filter_authorized_edges(edges, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      # Filter edges based on authorization
      results =
        Enum.reduce_while(edges, {[], []}, fn edge, {authorized, errors} ->
          case AccessControl.can?(graph, actor_id, edge.id, operation) do
            {:ok, true} -> {:cont, {[edge | authorized], errors}}
            {:ok, false} -> {:cont, {authorized, errors}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case results do
        {authorized, _} when is_list(authorized) ->
          {:ok, Enum.reverse(authorized)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Authorize a query before it is executed.

  ## Parameters

  - `query` - The query to authorize
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, authorized_query}` - Query is authorized, possibly modified
  - `{:error, reason}` - Error occurred during authorization
  """
  @impl true
  def authorize_query(query, _context) do
    # For now, simply pass through all queries
    {:ok, query}
  end

  @doc """
  Authorize a transaction before it is executed.

  ## Parameters

  - `transaction` - The transaction to authorize
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, authorized_transaction}` - Transaction is authorized, possibly modified
  - `{:error, reason}` - Error occurred during authorization
  """
  @impl true
  def authorize_transaction(transaction, _context) do
    # For now, pass through all transactions
    {:ok, transaction}
  end

  @doc """
  Authorize a subscription request.

  ## Parameters

  - `subscription` - The subscription parameters
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, authorized_subscription}` - Subscription is authorized, possibly modified
  - `{:error, reason}` - Error occurred during authorization
  """
  @impl true
  def authorize_subscription(subscription, _context) do
    # For now, allow all subscriptions
    {:ok, subscription}
  end

  @doc """
  Check access for a specific resource and operation.

  ## Parameters

  - `resource_id` - The ID of the resource to check access for
  - `operation` - The operation to check (e.g., :read, :write)
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Access is granted
  - `{:ok, false}` - Access is denied
  - `{:error, reason}` - Error occurred during check
  """
  @impl true
  def check_access(resource_id, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      AccessControl.can?(graph, actor_id, resource_id, operation)
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Filter results from a query based on access permissions.

  ## Parameters

  - `results` - The results to filter
  - `context` - Access context information

  ## Returns

  - `{:ok, filtered_results}` - Filtered results
  - `{:error, reason}` - Error occurred during filtering
  """
  @impl true
  def filter_results(results, context) do
    # For now, implement a simple filter
    cond do
      is_list(results) ->
        # If results is a list, filter nodes and edges separately
        nodes =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct == GraphOS.Graph.Node
            _ -> false
          end)

        edges =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct == GraphOS.Graph.Edge
            _ -> false
          end)

        other =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct != GraphOS.Graph.Node && struct != GraphOS.Graph.Edge
            _ -> true
          end)

        with {:ok, authorized_nodes} <- filter_authorized_nodes(nodes, :read, context),
             {:ok, authorized_edges} <- filter_authorized_edges(edges, :read, context) do
          {:ok, authorized_nodes ++ authorized_edges ++ other}
        end

      true ->
        # For now, just pass through non-list results
        {:ok, results}
    end
  end
end
