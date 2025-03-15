defmodule GraphOS.Graph.Store.ETS do
  @moduledoc """
  Graph store implementation using ETS tables for storage.
  
  This module provides an implementation of the `GraphOS.Graph.Store` behavior
  using Erlang Term Storage (ETS) as the underlying storage mechanism.
  
  ETS provides efficient in-memory storage and is suitable for development and
  testing environments. For production use with large code bases, consider using
  a more robust storage backend.
  """
  
  @behaviour GraphOS.Graph.Store
  
  alias GraphOS.Graph.Store.Server
  require Logger
  
  # Add compatibility with GraphOS.Graph.Protocol for the Graph module
  def execute(transaction) do
    # This is a stub to make the GraphOS.Graph module work
    # Eventually, we'll need a proper implementation that translates between
    # the two interfaces
    {:ok, %{results: []}}
  end
  
  # Storage tables
  @nodes_table :graph_nodes
  @edges_table :graph_edges
  @metadata_table :graph_metadata
  
  @impl true
  def init(opts) do
    # Extract configuration
    config = %{
      name: Keyword.get(opts, :name, "default"),
      repo_path: Keyword.get(opts, :repo_path),
      branch: Keyword.get(opts, :branch),
      nodes_table: String.to_atom("#{@nodes_table}_#{Keyword.get(opts, :name, "default")}"),
      edges_table: String.to_atom("#{@edges_table}_#{Keyword.get(opts, :name, "default")}"),
      metadata_table: String.to_atom("#{@metadata_table}_#{Keyword.get(opts, :name, "default")}"),
    }
    
    # Create ETS tables if they don't exist
    :ets.new(config.nodes_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(config.edges_table, [:bag, :public, :named_table, read_concurrency: true])
    :ets.new(config.metadata_table, [:set, :public, :named_table])
    
    # Store metadata
    :ets.insert(config.metadata_table, {:repo_path, config.repo_path})
    :ets.insert(config.metadata_table, {:branch, config.branch})
    :ets.insert(config.metadata_table, {:initialized_at, DateTime.utc_now()})
    
    Logger.info("Initialized ETS store #{config.name} for #{config.repo_path}, branch: #{config.branch || "N/A"}")
    
    {:ok, config}
  end
  
  @impl true
  def add_node(state, node_id, type, attributes) do
    node_record = {node_id, type, attributes}
    :ets.insert(state.nodes_table, node_record)
    {:ok, node_id}
  end
  
  @impl true
  def add_edge(state, source_id, target_id, type, attributes) do
    edge_id = generate_edge_id(source_id, target_id, type)
    edge_record = {{source_id, target_id, type}, edge_id, attributes}
    :ets.insert(state.edges_table, edge_record)
    {:ok, edge_id}
  end
  
  @impl true
  def get_node(state, node_id) do
    case :ets.lookup(state.nodes_table, node_id) do
      [{^node_id, type, attributes}] ->
        {:ok, %{id: node_id, type: type, attributes: attributes}}
      [] ->
        {:error, :not_found}
    end
  end
  
  @impl true
  def get_nodes(state, filter) do
    nodes = :ets.tab2list(state.nodes_table)
    |> Enum.filter(fn {_id, type, attributes} ->
      matches_filter?({type, attributes}, filter)
    end)
    |> Enum.map(fn {id, type, attributes} ->
      %{id: id, type: type, attributes: attributes}
    end)
    
    {:ok, nodes}
  end
  
  @impl true
  def get_edge(state, source_id, target_id, type) do
    case :ets.lookup(state.edges_table, {source_id, target_id, type}) do
      [{{^source_id, ^target_id, ^type}, edge_id, attributes}] ->
        {:ok, %{
          id: edge_id,
          source_id: source_id,
          target_id: target_id,
          type: type,
          attributes: attributes
        }}
      [] ->
        {:error, :not_found}
    end
  end
  
  @impl true
  def get_edges(state, filter) do
    edges = :ets.tab2list(state.edges_table)
    |> Enum.filter(fn {{source_id, target_id, type}, _edge_id, attributes} ->
      matches_edge_filter?({source_id, target_id, type, attributes}, filter)
    end)
    |> Enum.map(fn {{source_id, target_id, type}, edge_id, attributes} ->
      %{
        id: edge_id,
        source_id: source_id,
        target_id: target_id,
        type: type,
        attributes: attributes
      }
    end)
    
    {:ok, edges}
  end
  
  @impl true
  def query(state, query_map, _opts \\ []) do
    # Find nodes matching the query
    {:ok, nodes} = get_nodes(state, query_map)
    
    # For each node, find connected edges and nodes
    result = Enum.map(nodes, fn node ->
      # Get outgoing edges
      outgoing_edges = get_outgoing_edges(state, node.id)
      
      # Get incoming edges
      incoming_edges = get_incoming_edges(state, node.id)
      
      # Return the node with its connections
      Map.merge(node, %{
        outgoing_edges: outgoing_edges,
        incoming_edges: incoming_edges
      })
    end)
    
    {:ok, result}
  end
  
  @impl true
  def delete_node(state, node_id) do
    # Delete the node
    :ets.delete(state.nodes_table, node_id)
    
    # Delete all edges connected to this node
    # This is inefficient with ETS, would be better with a proper graph database
    :ets.match_delete(state.edges_table, {{node_id, :_, :_}, :_, :_})  # Outgoing
    :ets.match_delete(state.edges_table, {{:_, node_id, :_}, :_, :_})  # Incoming
    
    :ok
  end
  
  @impl true
  def delete_edge(state, source_id, target_id, type) do
    :ets.delete(state.edges_table, {source_id, target_id, type})
    :ok
  end
  
  @impl true
  def clear(state) do
    :ets.delete_all_objects(state.nodes_table)
    :ets.delete_all_objects(state.edges_table)
    :ok
  end
  
  @impl true
  def get_all_nodes(state) do
    nodes = :ets.tab2list(state.nodes_table)
    |> Enum.map(fn {id, type, attributes} ->
      %{id: id, type: type, attributes: attributes}
    end)
    
    {:ok, nodes}
  end
  
  @impl true
  def get_all_edges(state) do
    edges = :ets.tab2list(state.edges_table)
    |> Enum.map(fn {{source_id, target_id, type}, edge_id, attributes} ->
      %{
        id: edge_id,
        source_id: source_id,
        target_id: target_id,
        type: type,
        attributes: attributes
      }
    end)
    
    {:ok, edges}
  end
  
  @impl true
  def get_metadata(state) do
    metadata = :ets.tab2list(state.metadata_table)
    |> Enum.into(%{}, fn {key, value} -> {key, value} end)
    
    {:ok, metadata}
  end
  
  # Helper functions
  
  # Generate a unique edge ID
  defp generate_edge_id(source_id, target_id, type) do
    "#{source_id}->#{target_id}:#{type}"
  end
  
  # Check if a node matches a filter
  defp matches_filter?({type, attributes}, filter) do
    # Type filter
    type_match = case Map.get(filter, :type) do
      nil -> true
      filter_type -> filter_type == type
    end
    
    # Attributes filter
    attr_match = 
      case Map.get(filter, :attributes) do
        nil -> true
        filter_attrs ->
          Enum.all?(filter_attrs, fn {key, value} ->
            Map.get(attributes, key) == value
          end)
      end
    
    # Custom ID filter if present
    id_match = 
      case Map.get(filter, :id) do
        nil -> true
        _ -> false  # ID matching handled separately in get_node/2
      end
    
    type_match && attr_match && id_match
  end
  
  # Check if an edge matches a filter
  defp matches_edge_filter?({source_id, target_id, type, attributes}, filter) do
    # Source ID filter
    source_match = case Map.get(filter, :source_id) do
      nil -> true
      filter_source -> filter_source == source_id
    end
    
    # Target ID filter
    target_match = case Map.get(filter, :target_id) do
      nil -> true
      filter_target -> filter_target == target_id
    end
    
    # Type filter
    type_match = case Map.get(filter, :type) do
      nil -> true
      filter_type -> filter_type == type
    end
    
    # Attributes filter
    attr_match = 
      case Map.get(filter, :attributes) do
        nil -> true
        filter_attrs ->
          Enum.all?(filter_attrs, fn {key, value} ->
            Map.get(attributes, key) == value
          end)
      end
    
    source_match && target_match && type_match && attr_match
  end
  
  # Get all outgoing edges from a node
  defp get_outgoing_edges(state, node_id) do
    :ets.match_object(state.edges_table, {{node_id, :_, :_}, :_, :_})
    |> Enum.map(fn {{source_id, target_id, type}, edge_id, attributes} ->
      %{
        id: edge_id,
        source_id: source_id,
        target_id: target_id,
        type: type,
        attributes: attributes
      }
    end)
  end
  
  # Get all incoming edges to a node
  defp get_incoming_edges(state, node_id) do
    # This is inefficient with ETS, would be better with a proper graph database
    # that has an index on both source and target
    :ets.tab2list(state.edges_table)
    |> Enum.filter(fn {{_, target, _}, _, _} -> target == node_id end)
    |> Enum.map(fn {{source_id, target_id, type}, edge_id, attributes} ->
      %{
        id: edge_id,
        source_id: source_id,
        target_id: target_id,
        type: type,
        attributes: attributes
      }
    end)
  end
end
