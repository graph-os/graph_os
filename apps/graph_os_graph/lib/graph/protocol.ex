defmodule GraphOS.Graph.Protocol do
  @moduledoc """
  A protocol for graph operations.
  """

  alias GraphOS.Graph.{Transaction, Operation, Node, Edge, Query}

  @callback init() :: :ok | {:error, term()}
  @callback execute(Transaction.t()) :: Transaction.result()
  @callback handle(Operation.message()) :: :ok | {:error, term()}
  @callback close() :: :ok | {:error, term()}

  # Query-related callbacks
  @callback query(Query.query_params()) :: Query.query_result()
  @callback get_node(Node.id()) :: {:ok, Node.t()} | {:error, term()}
  @callback get_edge(Edge.id()) :: {:ok, Edge.t()} | {:error, term()}
  @callback find_nodes_by_properties(map()) :: {:ok, list(Node.t())} | {:error, term()}

  # Algorithm-related callbacks
  @callback algorithm_traverse(Node.id(), keyword()) :: {:ok, list()} | {:error, term()}
  @callback algorithm_shortest_path(Node.id(), Node.id(), keyword()) :: {:ok, list(Node.t()), number()} | {:error, term()}
  @callback algorithm_connected_components(keyword()) :: {:ok, list(list(Node.t()))} | {:error, term()}
  @callback algorithm_minimum_spanning_tree(keyword()) :: {:ok, list(Edge.t()), number()} | {:error, term()}
end
