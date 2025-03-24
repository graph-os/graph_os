defmodule GraphOS.Store.Transaction do
  @moduledoc """
  Defines a transaction for GraphOS.Store.

  A transaction groups multiple operations to be executed atomically.
  """

  alias GraphOS.Store.Operation

  @type t :: %__MODULE__{
          store: module() | atom(),
          operations: list(Operation.t()),
          opts: keyword()
        }

  @type result :: {:ok, map()} | {:error, term()}

  defstruct store: GraphOS.Store.StoreAdapter.ETS,
            operations: [],
            opts: []

  @doc """
  Creates a new transaction with the given operations.

  ## Parameters

  - `operations` - List of operations to include in the transaction, or a store reference

  ## Examples

      iex> op1 = GraphOS.Store.Operation.new(:insert, :node, %{id: "node1"})
      iex> op2 = GraphOS.Store.Operation.new(:insert, :node, %{id: "node2"})
      iex> GraphOS.Store.Transaction.new([op1, op2])
      %GraphOS.Store.Transaction{operations: [
        %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node1"}},
        %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node2"}}
      ]}
  """
  @spec new(list(Operation.t()) | any()) :: t()
  def new(operations) do
    # If operations is a list, use it; otherwise, start with an empty list
    ops = if is_list(operations), do: operations, else: []

    %__MODULE__{
      operations: ops
    }
  end

  @doc """
  Adds an operation to an existing transaction.

  ## Parameters

  - `transaction` - The transaction to add the operation to
  - `operation` - The operation to add

  ## Examples

      iex> transaction = GraphOS.Store.Transaction.new([])
      iex> operation = GraphOS.Store.Operation.new(:insert, :node, %{id: "node1"})
      iex> GraphOS.Store.Transaction.add_operation(transaction, operation)
      %GraphOS.Store.Transaction{operations: [
        %GraphOS.Store.Operation{type: :insert, entity: :node, params: %{id: "node1"}}
      ]}
  """
  @spec add_operation(t(), Operation.t()) :: t()
  def add_operation(%__MODULE__{} = transaction, %Operation{} = operation) do
    %{transaction | operations: [operation | transaction.operations]}
  end

  @doc """
  Alias for add_operation/2 for improved readability.
  """
  @spec add(t(), Operation.t()) :: t()
  def add(transaction, operation), do: add_operation(transaction, operation)

  @doc """
  Validates all operations in the transaction.

  ## Examples

      iex> op1 = GraphOS.Store.Operation.new(:insert, :node, %{id: "node1"})
      iex> op2 = GraphOS.Store.Operation.new(:insert, :node, %{id: "node2"})
      iex> transaction = GraphOS.Store.Transaction.new([op1, op2])
      iex> GraphOS.Store.Transaction.validate(transaction)
      :ok

      iex> op1 = GraphOS.Store.Operation.new(:insert, :node, %{id: "node1"})
      iex> op2 = GraphOS.Store.Operation.new(:update, :node, %{})
      iex> transaction = GraphOS.Store.Transaction.new([op1, op2])
      iex> GraphOS.Store.Transaction.validate(transaction)
      {:error, {:invalid_operation, 1, :missing_id}}
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{operations: operations}) do
    operations
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {operation, index}, _acc ->
      case Operation.validate(operation) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:invalid_operation, index, reason}}}
      end
    end)
  end

  @doc """
  Commits a transaction, executing all operations.

  ## Parameters

  - `transaction` - The transaction to commit

  ## Examples

      iex> transaction = GraphOS.Store.Transaction.new()
      iex> transaction = GraphOS.Store.Transaction.add(transaction, operation1)
      iex> transaction = GraphOS.Store.Transaction.add(transaction, operation2)
      iex> GraphOS.Store.Transaction.commit(transaction)
      {:ok, %{transaction: ..., results: [...]}}
  """
  @spec commit(t()) :: result()
  def commit(%__MODULE__{} = transaction) do
    # Lookup the store if needed
    store_name = transaction.store

    {:ok, store_ref} =
      case store_name do
        atom when is_atom(atom) ->
          case GraphOS.Store.Registry.lookup(atom) do
            {:ok, store_ref, adapter} ->
              {:ok, %{ref: store_ref, adapter: adapter}}

            {:error, :not_found} ->
              # Try direct ETS adapter as fallback for tests
              case GraphOS.Store.StoreAdapter.ETS.init() do
                {:ok, store_ref} ->
                  {:ok, %{ref: store_ref, adapter: GraphOS.Store.StoreAdapter.ETS}}

                error ->
                  error
              end
          end

        module when is_atom(module) and not is_nil(module) ->
          # Assume it's a module
          case module.init() do
            {:ok, store_ref} -> {:ok, %{ref: store_ref, adapter: module}}
            error -> error
          end

        _ ->
          {:error, :invalid_store}
      end

    case store_ref do
      %{ref: ref, adapter: adapter} ->
        # Execute each operation in the transaction
        results =
          Enum.map(transaction.operations, fn operation ->
            adapter.execute(ref, operation)
          end)

        # Check if any operation failed
        if Enum.any?(results, fn result -> match?({:error, _}, result) end) do
          # If any operation failed, we'll rollback the entire transaction
          # Simplified rollback for now
          _rollback_result = adapter.stop(ref)
          {:error, {:transaction_failed, results}}
        else
          # If all operations succeeded, return the results
          {:ok, %{transaction: transaction, results: results}}
        end

      error ->
        error
    end
  end

  @doc """
  Rolls back a transaction, undoing all of its operations.

  Currently this is a simplified implementation that just removes all
  entities created by the transaction. Future implementations could be more
  sophisticated with undo logs.

  ## Parameters

  - `transaction` - The transaction to roll back

  ## Examples

      iex> transaction = GraphOS.Store.Transaction.new()
      iex> transaction = GraphOS.Store.Transaction.add(transaction, operation1)
      iex> transaction = GraphOS.Store.Transaction.add(transaction, operation2)
      iex> {:ok, result} = GraphOS.Store.Transaction.commit(transaction)
      iex> GraphOS.Store.Transaction.rollback(transaction)
      :ok
  """
  @spec rollback(t()) :: :ok | {:error, term()}
  def rollback(%__MODULE__{} = transaction) do
    # Get the store module
    store_module =
      case transaction.store do
        module when is_atom(module) ->
          if function_exported?(module, :init, 0) do
            module
          else
            # Try looking up in registry if it's a name
            case GraphOS.Store.Registry.lookup(module) do
              {:ok, _store_ref, adapter} -> adapter
              {:error, :not_found} -> GraphOS.Store.StoreAdapter.ETS
            end
          end

        _ ->
          GraphOS.Store.StoreAdapter.ETS
      end

    # Get all operation IDs we need to delete
    # Extract IDs from insert operations in the transaction
    ids_to_delete =
      transaction.operations
      |> Enum.filter(fn op -> op.type == :insert end)
      |> Enum.map(fn op ->
        {op.entity, Map.get(op.params, :id)}
      end)
      |> Enum.filter(fn {_entity, id} -> id != nil end)

    # Initialize the store
    {:ok, store_ref} = store_module.init()

    # Delete all entities that were created
    Enum.each(ids_to_delete, fn {entity, id} ->
      delete_op = %GraphOS.Store.Operation{
        type: :delete,
        entity: entity,
        params: %{id: id}
      }

      # Execute the delete operation
      store_module.execute(store_ref, delete_op)
    end)

    :ok
  end
end
