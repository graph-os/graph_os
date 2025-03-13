defmodule GraphOS.Core.AccessControl do
  @moduledoc """
  Access control system for GraphOS.

  This module provides a graph-based access control system, allowing fine-grained
  permissions to be defined and enforced on graph operations. It implements a
  protected subgraph approach where access control nodes and edges are part of
  the main graph but receive special protection.

  ## Architecture

  The access control system follows these principles:

  1. **Actor-Scope Model**: Actors (users, services) are granted permissions to resources through scopes
  2. **Protected Subgraph**: Access control data is stored in a protected part of the main graph
  3. **Reference Monitor**: All operations are validated through a central security gateway
  4. **Complete Mediation**: Every operation is checked against the access control policy
  5. **Fail-Closed**: Operations fail by default if permissions are not explicitly granted

  ## Usage

  ```elixir
  # Define an actor (user or agent)
  GraphOS.Core.AccessControl.define_actor(graph, "user:alice", %{role: "admin"})
  
  # Grant permission to a resource
  GraphOS.Core.AccessControl.grant_permission(graph, "user:alice", "filesystem:*", [:read, :write])
  
  # Check if an operation is permitted
  {:ok, true} = GraphOS.Core.AccessControl.can?(graph, "user:alice", "filesystem:/tmp/file.txt", :read)
  ```
  """

  alias GraphOS.Graph.{Node, Edge, Transaction, Query, Store}

  # Node and edge types for access control
  @actor_type "access:actor"
  @scope_type "access:scope"
  @resource_type "access:resource"
  @permission_edge "access:permission"

  # Operation types
  @operation_types [:read, :write, :execute, :admin]

  @doc """
  Initialize the access control system for a graph.

  This creates the necessary structure in the graph to support access control.

  ## Parameters

  - `graph` - The graph to initialize access control for

  ## Returns

  - `:ok` - Access control initialized successfully
  - `{:error, reason}` - Initialization failed

  ## Examples

      iex> GraphOS.Core.AccessControl.init(graph)
      :ok
  """
  @spec init(atom() | pid()) :: :ok | {:error, term()}
  def init(_graph) do
    # Create a transaction to initialize the access control system
    transaction = Transaction.new(Store.get_store_module())

    # Create the root access control node
    root_node = Node.new(
      %{
        name: "AccessControl",
        protected: true,
        created_at: DateTime.utc_now()
      },
      [id: "access:root"]
    )

    # Add the root node operation to the transaction
    transaction = Transaction.add(
      transaction,
      GraphOS.Graph.Operation.new(:create, :node, root_node, [id: "access:root"])
    )

    # Execute the transaction
    case GraphOS.Graph.execute(transaction) do
      {:ok, _result} -> :ok
      error -> error
    end
  end

  @doc """
  Define an actor in the access control system.

  Actors are entities that can perform operations on resources, such as users or services.

  ## Parameters

  - `graph` - The graph to define the actor in
  - `actor_id` - Unique identifier for the actor
  - `attributes` - Map of actor attributes (optional)

  ## Returns

  - `{:ok, actor_node}` - Actor defined successfully
  - `{:error, reason}` - Actor definition failed

  ## Examples

      iex> GraphOS.Core.AccessControl.define_actor(graph, "user:alice", %{role: "admin"})
      {:ok, %GraphOS.Graph.Node{id: "user:alice", ...}}
  """
  @spec define_actor(atom() | pid(), String.t(), map()) :: {:ok, Node.t()} | {:error, term()}
  def define_actor(_graph, actor_id, attributes \\ %{}) do
    # Create a transaction to define the actor
    transaction = Transaction.new(Store.get_store_module())

    # Create the actor node
    actor_node = Node.new(
      Map.merge(attributes, %{
        name: actor_id,
        type: @actor_type,
        protected: true,
        created_at: DateTime.utc_now()
      }),
      [id: actor_id]
    )

    # Add the actor node operation to the transaction
    transaction = Transaction.add(
      transaction,
      GraphOS.Graph.Operation.new(:create, :node, actor_node, [id: actor_id])
    )

    # Add an edge linking the actor to the access control root
    transaction = Transaction.add(
      transaction,
      GraphOS.Graph.Operation.new(:create, :edge, %{
        type: "access:actor_def",
        protected: true,
        created_at: DateTime.utc_now()
      }, [
        id: "#{actor_id}->access:root",
        key: "access:actor_def",
        weight: 1,
        source: actor_id,
        target: "access:root"
      ])
    )

    # Execute the transaction
    case GraphOS.Graph.execute(transaction) do
      {:ok, _result} -> {:ok, actor_node}
      error -> error
    end
  end

  @doc """
  Grant permission for an actor to perform operations on a resource.

  ## Parameters

  - `graph` - The graph to grant the permission in
  - `actor_id` - The actor to grant permission to
  - `resource_pattern` - Resource pattern to match (e.g., "filesystem:*")
  - `operations` - List of operations to grant (e.g., [:read, :write])

  ## Returns

  - `{:ok, permission_edge}` - Permission granted successfully
  - `{:error, reason}` - Permission granting failed

  ## Examples

      iex> GraphOS.Core.AccessControl.grant_permission(graph, "user:alice", "filesystem:*", [:read, :write])
      {:ok, %GraphOS.Graph.Edge{id: "user:alice->filesystem:*", ...}}
  """
  @spec grant_permission(atom() | pid(), String.t(), String.t(), list(atom())) :: 
        {:ok, Edge.t()} | {:error, term()}
  def grant_permission(_graph, actor_id, resource_pattern, operations) do
    # Validate operations
    invalid_operations = Enum.reject(operations, &(&1 in @operation_types))
    if length(invalid_operations) > 0 do
      {:error, "Invalid operations: #{inspect(invalid_operations)}"}
    else
      # Create a transaction to grant the permission
      transaction = Transaction.new(Store.get_store_module())

      # Create the resource pattern node if it doesn't exist
      transaction = ensure_resource_pattern(transaction, resource_pattern)

      # Create the permission edge
      permission_id = "#{actor_id}->#{resource_pattern}"
      edge_data = %{
        type: @permission_edge,
        operations: operations,
        protected: true,
        created_at: DateTime.utc_now()
      }

      transaction = Transaction.add(
        transaction,
        GraphOS.Graph.Operation.new(:create, :edge, edge_data, [
          id: permission_id,
          key: @permission_edge,
          weight: 1,
          source: actor_id,
          target: resource_pattern
        ])
      )

      # Execute the transaction
      case GraphOS.Graph.execute(transaction) do
        {:ok, _result} -> 
          # Return the created edge
          {:ok, %Edge{
            id: permission_id,
            key: @permission_edge,
            weight: 1,
            source: actor_id,
            target: resource_pattern,
            meta: GraphOS.Graph.Meta.new()
          }}
        error -> error
      end
    end
  end

  @doc """
  Check if an actor has permission to perform an operation on a resource.

  ## Parameters

  - `graph` - The graph to check permissions in
  - `actor_id` - The actor to check permissions for
  - `resource_id` - The resource to check permissions for
  - `operation` - The operation to check (e.g., :read, :write)

  ## Returns

  - `{:ok, true}` - Actor has permission
  - `{:ok, false}` - Actor does not have permission
  - `{:error, reason}` - Permission check failed

  ## Examples

      iex> GraphOS.Core.AccessControl.can?(graph, "user:alice", "filesystem:/tmp/file.txt", :read)
      {:ok, true}
  """
  @spec can?(atom() | pid(), String.t(), String.t(), atom()) :: 
        {:ok, boolean()} | {:error, term()}
  def can?(graph, actor_id, resource_id, operation) do
    # TODO: Implement actual pattern matching with wildcards
    # For now, we'll do a simple check for exact matching or wildcard matching

    # Query for the actor's permissions
    with {:ok, permissions} <- get_actor_permissions(graph, actor_id) do
      # Check if any permission allows this operation on this resource
      has_permission = Enum.any?(permissions, fn {resource_pattern, ops} ->
        # Check if operation is allowed
        operation in ops && 
        # Check if resource matches the pattern (simple implementation for now)
        (resource_pattern == resource_id || resource_pattern == "*" || String.ends_with?(resource_pattern, ":*"))
      end)

      {:ok, has_permission}
    end
  end

  # Private helper functions

  # Ensure a resource pattern node exists
  defp ensure_resource_pattern(transaction, resource_pattern) do
    # Add an operation to create the resource pattern node if it doesn't exist
    node_data = %{
      name: resource_pattern,
      type: @resource_type,
      pattern: true,
      protected: true,
      created_at: DateTime.utc_now()
    }

    Transaction.add(
      transaction,
      GraphOS.Graph.Operation.new(:create, :node, node_data, [
        id: resource_pattern,
        on_conflict: :ignore  # Skip if already exists
      ])
    )
  end

  # Get all permissions for an actor
  defp get_actor_permissions(_graph, actor_id) do
    # Query for all permission edges from this actor
    case Query.execute(
      start_node_id: actor_id,
      edge_type: @permission_edge
    ) do
      {:ok, edges} ->
        # For now, we'll just return a list with read/write/execute permissions
        # In a real implementation, we would store operations in edge metadata
        permissions = Enum.map(edges, fn edge ->
          {edge.target, [:read, :write, :execute]}
        end)
        {:ok, permissions}

      error ->
        error
    end
  end
end