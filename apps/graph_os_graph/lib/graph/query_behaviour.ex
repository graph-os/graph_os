defmodule GraphOS.Graph.QueryBehaviour do
  @moduledoc """
  Defines the behaviour for graph query implementations.

  This module specifies the callbacks that any graph query implementation must provide.
  It's used to ensure consistent interface for different query implementations and to facilitate testing.
  """

  @type query_params :: keyword() | map()
  @type query_result :: {:ok, list(map())} | {:error, term()}
  @type node_id :: String.t()
  @type edge_id :: String.t()
  @type node_t :: map()
  @type edge_t :: map()

  @doc """
  Execute a query against the graph.
  """
  @callback execute(query_params()) :: query_result()

  @doc """
  Get a node by ID.
  """
  @callback get_node(node_id()) :: {:ok, node_t()} | {:error, term()}

  @doc """
  Get an edge by ID.
  """
  @callback get_edge(edge_id()) :: {:ok, edge_t()} | {:error, term()}

  @doc """
  Find nodes by property values.
  """
  @callback find_nodes_by_properties(map()) :: {:ok, list(node_t())} | {:error, term()}
end
