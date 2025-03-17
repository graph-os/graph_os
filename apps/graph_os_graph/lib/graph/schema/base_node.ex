defmodule GraphOS.Graph.Schema.BaseNode do
  @moduledoc """
  Base schema for nodes in the graph.
  
  This schema defines the basic fields that all nodes should have.
  Other schema modules can build on top of this by including these 
  fields in their own definitions.
  """
  
  @behaviour GraphOS.Graph.SchemaBehaviour
  
  @doc """
  Returns the base fields for a node.
  """
  @impl true
  def fields do
    [
      {:id, :string, [required: true, description: "Unique identifier for the node"]},
      {:key, :string, [description: "Optional key for the node"]},
      {:data, :map, [required: true, description: "Node data"]},
      {:meta, :map, [required: true, description: "Node metadata"]}
    ]
  end
  
  @doc """
  Returns the Protocol Buffer definition for the base node.
  """
  @impl true
  def proto_definition do
    """
    syntax = "proto3";
    
    // BaseNode represents the fundamental node structure in the graph
    message BaseNode {
      string id = 1;          // Unique identifier for the node
      string key = 2;         // Optional key for the node
      bytes data = 3;         // Node data (serialized as bytes)
      bytes meta = 4;         // Node metadata (serialized as bytes)
    }
    """
  end
  
  @doc """
  Returns the mapping between Protocol Buffer fields and schema fields.
  """
  @impl true
  def proto_field_mapping do
    %{
      "id" => :id,
      "key" => :key,
      "data" => :data,
      "meta" => :meta
    }
  end
  
  @doc """
  Introspects the schema.
  """
  @impl true
  def introspect do
    %{
      name: "BaseNode",
      fields: fields(),
      description: "Base schema for nodes in the graph",
      is_abstract: true,
      proto_definition: proto_definition(),
      proto_field_mapping: proto_field_mapping()
    }
  end
end