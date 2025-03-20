defmodule GraphOS.GraphContext.Schema.BaseEdge do
  @moduledoc """
  Base schema for edges in the graph.
  
  This schema defines the basic fields that all edges should have.
  Other schema modules can build on top of this by including these 
  fields in their own definitions.
  """
  
  @behaviour GraphOS.GraphContext.SchemaBehaviour
  
  @doc """
  Returns the base fields for an edge.
  """
  @impl true
  def fields do
    [
      {:id, :string, [required: true, description: "Unique identifier for the edge"]},
      {:source_id, :string, [required: true, description: "ID of the source node"]},
      {:target_id, :string, [required: true, description: "ID of the target node"]},
      {:type, :string, [required: true, description: "Type of relationship"]},
      {:data, :map, [description: "Additional edge data"]},
      {:meta, :map, [required: true, description: "Edge metadata"]}
    ]
  end
  
  @doc """
  Returns the Protocol Buffer definition for the base edge.
  """
  @impl true
  def proto_definition do
    """
    syntax = "proto3";
    
    // BaseEdge represents the fundamental edge structure in the graph
    message BaseEdge {
      string id = 1;          // Unique identifier for the edge
      string source_id = 2;   // ID of the source node
      string target_id = 3;   // ID of the target node
      string type = 4;        // Type of relationship
      bytes data = 5;         // Additional edge data (serialized as bytes)
      bytes meta = 6;         // Edge metadata (serialized as bytes)
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
      "source_id" => :source_id,
      "target_id" => :target_id,
      "type" => :type,
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
      name: "BaseEdge",
      fields: fields(),
      description: "Base schema for edges in the graph",
      is_abstract: true,
      proto_definition: proto_definition(),
      proto_field_mapping: proto_field_mapping()
    }
  end
end