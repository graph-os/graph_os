defmodule GraphOS.Graph.Protocol do
  @moduledoc """
  Protocol for graph operations.
  
  This protocol defines the interface for storage implementations to support
  the core graph operations. It focuses on the three main aspects of the graph library:
  
  1. Operations - Individual atomic changes to the graph
  2. Transactions - Groups of operations processed as a unit 
  3. Queries - Read operations to traverse and retrieve graph data
  
  Each implementation must support these three core interfaces and their related
  algorithm functionality.
  """
  
  use Boundary, deps: []

  alias GraphOS.Graph.{Transaction, Operation, Node, Edge, Query}

  # Core protocol callbacks
  @callback init(opts :: keyword()) :: {:ok, map()} | :ok | {:error, term()}
  @callback execute(Transaction.t()) :: Transaction.result()
  @callback handle(Operation.message()) :: :ok | {:error, term()}
  @callback close() :: :ok | {:error, term()}

  # Query-related callbacks
  @callback query(Query.query_params()) :: Query.query_result()
  @callback get_node(Node.id()) :: {:ok, Node.t()} | {:error, term()}
  @callback get_edge(Edge.id()) :: {:ok, Edge.t()} | {:error, term()}
  @callback find_nodes_by_properties(map()) :: {:ok, list(Node.t())} | {:error, term()}

  # Algorithm-related callbacks - these support the Query interface
  @callback algorithm_traverse(Node.id(), keyword()) :: {:ok, list()} | {:error, term()}
  @callback algorithm_shortest_path(Node.id(), Node.id(), keyword()) :: {:ok, list(Node.t()), number()} | {:error, term()}
  @callback algorithm_connected_components(keyword()) :: {:ok, list(list(Node.t()))} | {:error, term()}
  @callback algorithm_minimum_spanning_tree(keyword()) :: {:ok, list(Edge.t()), number()} | {:error, term()}
end
