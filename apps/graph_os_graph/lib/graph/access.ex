defmodule GraphOS.Core.Access do
  @moduledoc """
  Access control system for GraphOS.

  This module provides the core access control functionality for GraphOS,
  implementing a graph-based access control system where actors and scopes
  are nodes and permissions are edges in a protected subgraph.

  ## Usage

  ```elixir
  # Initialize access control for a graph
  GraphOS.Core.Access.init(graph)

  # Define an actor (user or agent)
  GraphOS.Core.Access.define_actor(graph, "user:alice", %{role: "admin"})

  # Grant permission to a resource
  GraphOS.Core.Access.grant_permission(graph, "user:alice", "filesystem:*", [:read, :write])

  # Check if an operation is permitted
  {:ok, true} = GraphOS.Core.Access.can?(graph, "user:alice", "filesystem:/tmp/file.txt", :read)

  # Use with graph operations
  access_context = %{actor_id: "user:alice", graph: graph}
  GraphOS.GraphContext.Store.query(params, GraphOS.GraphContext.Store.ETS,
    access_control: GraphOS.Core.Access,
    access_context: access_context
  )
  ```
  """

  alias GraphOS.GraphContext.{Node, Edge, Operation, Transaction}

  # Node and edge types for access control
  @actor_type "access:actor"
  @scope_type "access:scope"
  @permission_edge "access:permission"

  # Operation types
  @operation_types [:read, :write, :execute, :admin]

  @doc """
  Initialize the access control system for a graph.
  """
  def init(graph) do
    transaction = Transaction.new(GraphOS.GraphContext.Store.ETS)

    # Create the root access control node
    root_node =
      Node.new(
        %{
          name: "AccessControl",
          protected: true,
          created_at: DateTime.utc_now()
        },
        id: "access:root"
      )

    transaction =
      Transaction.add(
        transaction,
        Operation.new(:create, :node, root_node, id: "access:root")
      )

    case GraphOS.GraphContext.execute(transaction) do
      {:ok, _result} -> :ok
      error -> error
    end
  end

  @doc """
  Define an actor in the access control system.
  """
  def define_actor(graph, actor_id, attributes \\ %{}) do
    transaction = Transaction.new(GraphOS.GraphContext.Store.ETS)

    actor_node =
      Node.new(
        Map.merge(attributes, %{
          name: actor_id,
          type: @actor_type,
          protected: true,
          created_at: DateTime.utc_now()
        }),
        id: actor_id
      )

    transaction =
      Transaction.add(
        transaction,
        Operation.new(:create, :node, actor_node, id: actor_id)
      )

    transaction =
      Transaction.add(
        transaction,
        Operation.new(
          :create,
          :edge,
          %{
            type: "access:actor_def",
            protected: true,
            created_at: DateTime.utc_now()
          },
          id: "#{actor_id}->access:root",
          key: "access:actor_def",
          weight: 1,
          source: actor_id,
          target: "access:root"
        )
      )

    case GraphOS.GraphContext.execute(transaction) do
      {:ok, _result} -> {:ok, actor_node}
      error -> error
    end
  end

  @doc """
  Define a scope in the access control system.
  """
  def define_scope(graph, scope_id, attributes \\ %{}) do
    transaction = Transaction.new(GraphOS.GraphContext.Store.ETS)

    scope_node =
      Node.new(
        Map.merge(attributes, %{
          name: scope_id,
          type: @scope_type,
          protected: true,
          created_at: DateTime.utc_now()
        }),
        id: scope_id
      )

    transaction =
      Transaction.add(
        transaction,
        Operation.new(:create, :node, scope_node, id: scope_id)
      )

    transaction =
      Transaction.add(
        transaction,
        Operation.new(
          :create,
          :edge,
          %{
            type: "access:scope_def",
            protected: true,
            created_at: DateTime.utc_now()
          },
          id: "#{scope_id}->access:root",
          key: "access:scope_def",
          weight: 1,
          source: scope_id,
          target: "access:root"
        )
      )

    case GraphOS.GraphContext.execute(transaction) do
      {:ok, _result} -> {:ok, scope_node}
      error -> error
    end
  end

  @doc """
  Grant permission for an actor to perform operations on a scope.
  """
  def grant_permission(graph, actor_id, scope_id, operations) do
    invalid_operations = Enum.reject(operations, &(&1 in @operation_types))

    if length(invalid_operations) > 0 do
      {:error, "Invalid operations: #{inspect(invalid_operations)}"}
    else
      transaction = Transaction.new(GraphOS.GraphContext.Store.ETS)
      transaction = ensure_scope(transaction, scope_id)

      permission_id = "#{actor_id}->#{scope_id}"

      edge_data = %{
        type: @permission_edge,
        operations: operations,
        protected: true,
        created_at: DateTime.utc_now()
      }

      transaction =
        Transaction.add(
          transaction,
          Operation.new(:create, :edge, edge_data,
            id: permission_id,
            key: @permission_edge,
            weight: 1,
            source: actor_id,
            target: scope_id
          )
        )

      case GraphOS.GraphContext.execute(transaction) do
        {:ok, _result} ->
          {:ok,
           %Edge{
             id: permission_id,
             key: @permission_edge,
             weight: 1,
             source: actor_id,
             target: scope_id,
             meta: GraphOS.GraphContext.Meta.new()
           }}

        error ->
          error
      end
    end
  end

  @doc """
  Check if an actor has permission to perform an operation on a scope.
  """
  def can?(graph, actor_id, scope_id, operation) do
    with {:ok, permissions} <- get_actor_permissions(graph, actor_id) do
      has_permission =
        Enum.any?(permissions, fn {resource_pattern, ops} ->
          operation in ops &&
            (resource_pattern == scope_id || resource_pattern == "*" ||
               String.ends_with?(resource_pattern, ":*") ||
               resource_pattern_match?(resource_pattern, scope_id))
        end)

      {:ok, has_permission}
    end
  end

  @doc """
  Authorize a graph operation.
  """
  def authorize_operation(%Operation{} = operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      case operation do
        %{action: :create, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          can?(graph, actor_id, "graph:#{graph}", :write)

        %{action: :update, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          can?(graph, actor_id, node_id, :write)

        %{action: :delete, entity: :node, opts: opts} ->
          node_id = Keyword.get(opts, :id)
          can?(graph, actor_id, node_id, :write)

        %{action: :create, entity: :edge, opts: opts} ->
          source = Keyword.get(opts, :source)
          target = Keyword.get(opts, :target)

          with {:ok, source_auth} <- can?(graph, actor_id, source, :write),
               {:ok, target_auth} <- can?(graph, actor_id, target, :read) do
            {:ok, source_auth && target_auth}
          end

        %{action: :update, entity: :edge, opts: opts} ->
          edge_id = Keyword.get(opts, :id)
          can?(graph, actor_id, edge_id, :write)

        %{action: :delete, entity: :edge, opts: opts} ->
          edge_id = Keyword.get(opts, :id)
          can?(graph, actor_id, edge_id, :write)

        _ ->
          {:ok, false}
      end
    else
      {:error, :missing_actor_or_graph}
    end
  end

  @doc """
  Filter results based on access permissions.
  """
  def filter_results(results, context) do
    cond do
      is_list(results) ->
        nodes =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct == Node
            _ -> false
          end)

        edges =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct == Edge
            _ -> false
          end)

        other =
          Enum.filter(results, fn
            %{__struct__: struct} -> struct != Node && struct != Edge
            _ -> true
          end)

        with {:ok, authorized_nodes} <- filter_authorized_nodes(nodes, :read, context),
             {:ok, authorized_edges} <- filter_authorized_edges(edges, :read, context) do
          {:ok, authorized_nodes ++ authorized_edges ++ other}
        end

      true ->
        {:ok, results}
    end
  end

  # Private helper functions

  defp ensure_scope(transaction, scope_id) do
    node_data = %{
      name: scope_id,
      type: @scope_type,
      pattern: true,
      protected: true,
      created_at: DateTime.utc_now()
    }

    Transaction.add(
      transaction,
      Operation.new(:create, :node, node_data,
        id: scope_id,
        on_conflict: :ignore
      )
    )
  end

  defp get_actor_permissions(_graph, actor_id) do
    case GraphOS.GraphContext.Query.execute(
           start_node_id: actor_id,
           edge_type: @permission_edge
         ) do
      {:ok, edges} ->
        permissions =
          Enum.map(edges, fn edge ->
            {edge.target, [:read, :write, :execute]}
          end)

        {:ok, permissions}

      error ->
        error
    end
  end

  defp resource_pattern_match?(pattern, scope_id) do
    if String.ends_with?(pattern, "*") do
      prefix = String.replace_suffix(pattern, "*", "")
      String.starts_with?(scope_id, prefix)
    else
      pattern == scope_id
    end
  end

  defp filter_authorized_nodes(nodes, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      results =
        Enum.reduce_while(nodes, {[], []}, fn node, {authorized, errors} ->
          case can?(graph, actor_id, node.id, operation) do
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

  defp filter_authorized_edges(edges, operation, context) do
    actor_id = Map.get(context, :actor_id)
    graph = Map.get(context, :graph)

    if actor_id && graph do
      results =
        Enum.reduce_while(edges, {[], []}, fn edge, {authorized, errors} ->
          case can?(graph, actor_id, edge.id, operation) do
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
end
