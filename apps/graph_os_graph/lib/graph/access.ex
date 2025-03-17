defmodule GraphOS.Graph.Access do
  @moduledoc """
  Behaviour defining the graph access control interface.

  This module defines the contract for access control implementations that can be
  used with GraphOS.Graph. It focuses on the core interfaces: Transaction, Operation,
  Query, and Subscription, rather than directly on nodes and edges.

  ## Usage

  Implement this behaviour in your access control module:

  ```elixir
  defmodule MyAccessControl do
    @behaviour GraphOS.Graph.Access
    
    @impl true
    def authorize_query(query, context) do
      # Your query authorization logic
      {:ok, true}
    end
    
    # Implement other callback functions...
  end
  ```

  Then pass the module to graph operations:

  ```elixir
  GraphOS.Graph.query(params, access_control: MyAccessControl)
  ```
  """

  alias GraphOS.Graph.{Operation, Query, Transaction, Subscription}

  @type context :: map()
  @type result :: {:ok, boolean()} | {:error, term()}
  @type entity_id :: String.t()
  @type operation_type :: :read | :write | :admin
  @type pattern :: String.t()

  @doc """
  Authorize a query operation before it is executed.

  ## Parameters

  - `query` - The query to authorize
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Query is authorized
  - `{:ok, false}` - Query is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  @callback authorize_query(Query.query_params(), context()) :: result()

  @doc """
  Authorize a transaction before it is executed.

  ## Parameters

  - `transaction` - The transaction to authorize
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Transaction is authorized
  - `{:ok, false}` - Transaction is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  @callback authorize_transaction(Transaction.t(), context()) :: result()

  @doc """
  Authorize a single operation before it is executed.

  ## Parameters

  - `operation` - The operation to authorize
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Operation is authorized
  - `{:ok, false}` - Operation is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  @callback authorize_operation(Operation.t(), context()) :: result()

  @doc """
  Authorize a subscription request.

  ## Parameters

  - `topic` - The topic to subscribe to
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Subscription is authorized
  - `{:ok, false}` - Subscription is not authorized
  - `{:error, reason}` - Error occurred during authorization
  """
  @callback authorize_subscription(Subscription.topic(), context()) :: result()

  @doc """
  Filter results of a query based on access permissions.

  ## Parameters

  - `results` - The results to filter
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, filtered_results}` - Filtered results
  - `{:error, reason}` - Error occurred during filtering
  """
  @callback filter_results(term(), context()) :: {:ok, term()} | {:error, term()}

  @doc """
  Check if an entity is accessible for a specific operation type.

  ## Parameters

  - `entity_id` - The ID of the entity to check
  - `operation_type` - The type of operation (:read, :write, :admin)
  - `context` - Additional context for the authorization decision

  ## Returns

  - `{:ok, true}` - Access is granted
  - `{:ok, false}` - Access is denied
  - `{:error, reason}` - Error occurred during check
  """
  @callback check_access(entity_id(), operation_type(), context()) :: result()

  @doc """
  Initialize the access control system.

  ## Parameters

  - `opts` - Options for initialization

  ## Returns

  - `:ok` - Successfully initialized
  - `{:error, reason}` - Error occurred during initialization
  """
  @callback init(keyword()) :: :ok | {:error, term()}
end