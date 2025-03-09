defmodule GraphOS.Graph.Store.ETS do
  @moduledoc """
  An ETS-based implementation of the GraphOS.Graph.Store behaviour.

  This module provides an in-memory storage solution for GraphOS graphs using Erlang Term Storage (ETS).
  """

  @behaviour GraphOS.Graph.Protocol

  alias GraphOS.Graph.{Node, Edge, Transaction, Operation}

  @table_name :graph_os_ets_store

  @impl true
  def init do
    case :ets.info(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:set, :public, :named_table])
        :ok
      _ ->
        :ok
    end
  end

  @impl true
  def execute(%Transaction{} = transaction) do
    # Process each operation in the transaction
    results = Enum.map(transaction.operations, &handle/1)

    # Check if any operation failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, %{results: results}}
      error -> error
    end
  end

  @doc """
  Rollback a transaction by reversing its operations.

  This is a simplistic implementation that doesn't handle all possible rollback scenarios.
  In a production system, you would need to implement proper rollback logic for each operation type.
  """
  def rollback(%Transaction{} = transaction) do
    # Reverse operations to undo them in the opposite order they were applied
    operations = Enum.reverse(transaction.operations)

    # Create rollback operations
    rollback_operations = Enum.map(operations, &create_rollback_operation/1)

    # Execute rollback operations
    results = Enum.map(rollback_operations, &handle/1)

    # Check if any rollback operation failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  # Create a rollback operation for each operation type
  defp create_rollback_operation(%Operation{action: :create, entity: entity, data: _data, opts: opts}) do
    # For a create operation, the rollback is a delete
    id = Keyword.get(opts, :id)
    Operation.new(:delete, entity, %{}, [id: id])
  end

  defp create_rollback_operation(%Operation{action: :update, entity: entity, data: _data, opts: opts}) do
    # For an update, we would ideally restore the previous state
    # This is a simplified version that just flags it as rolled back
    id = Keyword.get(opts, :id)

    # In a real system, you would fetch the original state and restore it
    # Here we just add a flag indicating it was rolled back
    case entity do
      :node ->
        case :ets.lookup(@table_name, {:node, id}) do
          [{{:node, ^id}, node}] ->
            meta = %{node.meta | updated_at: DateTime.utc_now(), version: node.meta.version + 1}
            rollback_data = Map.put(node.data, :_rollback, true)
            Operation.new(:update, entity, rollback_data, [id: id, meta: meta])
          [] ->
            Operation.new(:noop, entity, %{}, [id: id])
        end
      :edge ->
        case :ets.lookup(@table_name, {:edge, id}) do
          [{{:edge, ^id}, edge}] ->
            meta = %{edge.meta | updated_at: DateTime.utc_now(), version: edge.meta.version + 1}
            Operation.new(:update, entity, %{}, [id: id, meta: meta])
          [] ->
            Operation.new(:noop, entity, %{}, [id: id])
        end
    end
  end

  defp create_rollback_operation(%Operation{action: :delete, entity: entity, data: data, opts: opts}) do
    # For a delete, the rollback would be to recreate the entity
    # This is only possible if we have cached the deleted entity
    # In this simplified version, we can't truly restore the deleted entity
    Operation.new(:noop, entity, data, opts)
  end

  defp create_rollback_operation(operation) do
    # For other operations, just create a no-op
    %{operation | action: :noop}
  end

  @impl true
  def handle(%Operation{} = operation) do
    handle_operation(operation.action, operation.entity, operation.data, operation.opts)
  end

  @impl true
  def handle(operation_message) when is_tuple(operation_message) do
    operation = Operation.from_message(operation_message)
    handle(operation)
  end

  # Handle create operations
  defp handle_operation(:create, :node, data, opts) do
    node = Node.new(data, opts)
    :ets.insert(@table_name, {{:node, node.id}, node})
    {:ok, node}
  end

  defp handle_operation(:create, :edge, _data, opts) do
    source = Keyword.get(opts, :source)
    target = Keyword.get(opts, :target)

    if source && target do
      edge = Edge.new(source, target, opts)
      :ets.insert(@table_name, {{:edge, edge.id}, edge})
      {:ok, edge}
    else
      {:error, :missing_source_or_target}
    end
  end

  # Handle update operations
  defp handle_operation(:update, :node, data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      case :ets.lookup(@table_name, {:node, id}) do
        [{{:node, ^id}, node}] ->
          updated_node = %{node | data: Map.merge(node.data, data)}
          updated_node = %{updated_node | meta: %{updated_node.meta |
            updated_at: DateTime.utc_now(),
            version: updated_node.meta.version + 1
          }}
          :ets.insert(@table_name, {{:node, id}, updated_node})
          {:ok, updated_node}
        [] ->
          {:error, :node_not_found}
      end
    else
      {:error, :missing_id}
    end
  end

  defp handle_operation(:update, :edge, _data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      case :ets.lookup(@table_name, {:edge, id}) do
        [{{:edge, ^id}, edge}] ->
          # Handle any specific edge updates if needed
          updated_edge = edge

          # Apply metadata updates
          updated_edge = %{updated_edge | meta: %{updated_edge.meta |
            updated_at: DateTime.utc_now(),
            version: updated_edge.meta.version + 1
          }}

          :ets.insert(@table_name, {{:edge, id}, updated_edge})
          {:ok, updated_edge}
        [] ->
          {:error, :edge_not_found}
      end
    else
      {:error, :missing_id}
    end
  end

  # Handle delete operations
  defp handle_operation(:delete, :node, _data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      :ets.delete(@table_name, {:node, id})
      {:ok, id}
    else
      {:error, :missing_id}
    end
  end

  defp handle_operation(:delete, :edge, _data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      :ets.delete(@table_name, {:edge, id})
      {:ok, id}
    else
      {:error, :missing_id}
    end
  end

  # Handle get operations (not part of standard CRUD actions but useful)
  defp handle_operation(:get, :node, _data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      case :ets.lookup(@table_name, {:node, id}) do
        [{{:node, ^id}, node}] -> {:ok, node}
        [] -> {:error, :node_not_found}
      end
    else
      {:error, :missing_id}
    end
  end

  defp handle_operation(:get, :edge, _data, opts) do
    id = Keyword.get(opts, :id)

    if id do
      case :ets.lookup(@table_name, {:edge, id}) do
        [{{:edge, ^id}, edge}] -> {:ok, edge}
        [] -> {:error, :edge_not_found}
      end
    else
      {:error, :missing_id}
    end
  end

  # Handle no-op operation (used mainly for rollbacks)
  defp handle_operation(:noop, _entity, _data, _opts) do
    {:ok, :noop}
  end

  # Fallback for unknown operations
  defp handle_operation(action, entity, _data, _opts) do
    {:error, {:unknown_operation, action, entity}}
  end

  @impl true
  def close do
    case :ets.info(@table_name) do
      :undefined -> :ok
      _ ->
        :ets.delete(@table_name)
        :ok
    end
  end
end
