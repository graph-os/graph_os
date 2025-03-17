defmodule GraphOS.Protocol.SchemaTest do
  use ExUnit.Case, async: true
  
  alias GraphOS.Protocol.Schema
  alias GraphOS.Graph.Schema.TestPersonSchema
  
  # Create struct modules to match the test expectations
  defmodule GetNodeRequest do
    @moduledoc "Proto message for test purposes"
    defstruct [:id]
  end
  
  defmodule ListNodesRequest do
    @moduledoc "Proto message for test purposes"
    defstruct [:type, :limit, :cursor]
  end
  
  defmodule CreateNodeRequest do
    @moduledoc "Proto message for test purposes"
    defstruct [:type, :data]
  end
  
  # Create a simplified adapter module to work with the schema system
  defmodule TestSchemaAdapter do
    @moduledoc "Test adapter for schema protocol upgrading"
    
    # Forward schema_behaviour and protocol_buffer methods
    def upgrade_to_jsonrpc(proto_msg, "GetNode") do
      %{
        "jsonrpc" => "2.0",
        "method" => "graph.query.nodes.get",
        "params" => %{"id" => proto_msg.id}
      }
    end
    
    def upgrade_to_jsonrpc(proto_msg, "ListNodes") do
      params = %{}
      params = if proto_msg.type, do: Map.put(params, "type", proto_msg.type), else: params
      params = if proto_msg.limit, do: Map.put(params, "limit", proto_msg.limit), else: params
      params = if proto_msg.cursor, do: Map.put(params, "cursor", proto_msg.cursor), else: params
      
      %{
        "jsonrpc" => "2.0",
        "method" => "graph.query.nodes.list",
        "params" => params
      }
    end
    
    def upgrade_to_jsonrpc(proto_msg, "CreateNode") do
      %{
        "jsonrpc" => "2.0",
        "method" => "graph.action.nodes.create",
        "params" => %{
          "type" => proto_msg.type,
          "data" => proto_msg.data
        }
      }
    end
    
    def upgrade_to_plug(proto_msg, "GetNode") do
      %{
        path_params: %{"path" => "nodes/#{proto_msg.id}"},
        query_params: %{},
        body_params: %{}
      }
    end
    
    def upgrade_to_plug(proto_msg, "ListNodes") do
      query_params = %{}
      query_params = if proto_msg.type, do: Map.put(query_params, "type", proto_msg.type), else: query_params
      query_params = if proto_msg.limit, do: Map.put(query_params, "limit", proto_msg.limit), else: query_params
      query_params = if proto_msg.cursor, do: Map.put(query_params, "cursor", proto_msg.cursor), else: query_params
      
      %{
        path_params: %{"path" => "nodes"},
        query_params: query_params,
        body_params: %{}
      }
    end
    
    def upgrade_to_plug(proto_msg, "CreateNode") do
      %{
        path_params: %{"path" => "nodes"},
        query_params: %{},
        body_params: %{
          "type" => proto_msg.type,
          "data" => proto_msg.data
        }
      }
    end
    
    def upgrade_to_mcp(proto_msg, "GetNode") do
      %{
        "type" => "Node",
        "context" => %{
          "operation" => "get",
          "id" => proto_msg.id
        },
        "data" => %{}
      }
    end
    
    def upgrade_to_mcp(proto_msg, "ListNodes") do
      context = %{"operation" => "list"}
      context = if proto_msg.type, do: Map.put(context, "type", proto_msg.type), else: context
      context = if proto_msg.limit, do: Map.put(context, "limit", proto_msg.limit), else: context
      context = if proto_msg.cursor, do: Map.put(context, "cursor", proto_msg.cursor), else: context
      
      %{
        "type" => "NodeList",
        "context" => context,
        "data" => %{}
      }
    end
    
    def upgrade_to_mcp(proto_msg, "CreateNode") do
      %{
        "type" => "Node",
        "context" => %{
          "operation" => "create"
        },
        "data" => %{
          "type" => proto_msg.type,
          "data" => proto_msg.data
        }
      }
    end
  end
  
  describe "Protocol Schema upgrade functions" do
    test "upgrade_to_jsonrpc/3 converts protobuf message to JSON-RPC format" do
      # Create a Protocol Buffer message
      proto_msg = %GetNodeRequest{id: "node-1"}
      
      # Use the schema upgrade function
      result = Schema.upgrade_to_jsonrpc(proto_msg, "GetNode", TestSchemaAdapter)
      
      # Verify the result
      assert result == %{
        "jsonrpc" => "2.0",
        "method" => "graph.query.nodes.get", 
        "params" => %{"id" => "node-1"}
      }
    end
    
    test "upgrade_to_plug/3 converts protobuf message to Plug format" do
      # Create a Protocol Buffer message
      proto_msg = %GetNodeRequest{id: "node-1"}
      
      # Use the schema upgrade function
      result = Schema.upgrade_to_plug(proto_msg, "GetNode", TestSchemaAdapter)
      
      # Verify the result
      assert result == %{
        path_params: %{"path" => "nodes/node-1"},
        query_params: %{},
        body_params: %{}
      }
    end
    
    test "upgrade_to_mcp/3 converts protobuf message to MCP format" do
      # Create a Protocol Buffer message
      proto_msg = %GetNodeRequest{id: "node-1"}
      
      # Use the schema upgrade function
      result = Schema.upgrade_to_mcp(proto_msg, "GetNode", TestSchemaAdapter)
      
      # Verify the result
      assert result == %{
        "type" => "Node",
        "context" => %{
          "operation" => "get",
          "id" => "node-1"
        },
        "data" => %{}
      }
    end
  end
  
  describe "Different Protocol Buffer message types" do
    test "ListNodes request is properly upgraded to different formats" do
      # Create a Protocol Buffer message
      proto_msg = %ListNodesRequest{
        type: "person",
        limit: 10
      }
      
      # JSON-RPC
      jsonrpc = Schema.upgrade_to_jsonrpc(proto_msg, "ListNodes", TestSchemaAdapter)
      assert jsonrpc["method"] == "graph.query.nodes.list"
      assert jsonrpc["params"]["type"] == "person"
      assert jsonrpc["params"]["limit"] == 10
      
      # Plug
      plug = Schema.upgrade_to_plug(proto_msg, "ListNodes", TestSchemaAdapter)
      assert plug[:path_params]["path"] == "nodes"
      assert plug[:query_params]["type"] == "person"
      assert plug[:query_params]["limit"] == 10
      
      # MCP
      mcp = Schema.upgrade_to_mcp(proto_msg, "ListNodes", TestSchemaAdapter)
      assert mcp["type"] == "NodeList"
      assert mcp["context"]["operation"] == "list"
      assert mcp["context"]["type"] == "person"
      assert mcp["context"]["limit"] == 10
    end
    
    test "CreateNode request is properly upgraded to different formats" do
      # Create a Protocol Buffer message
      proto_msg = %CreateNodeRequest{
        type: "person",
        data: %{"name" => "Charlie", "age" => 35}
      }
      
      # JSON-RPC
      jsonrpc = Schema.upgrade_to_jsonrpc(proto_msg, "CreateNode", TestSchemaAdapter)
      assert jsonrpc["method"] == "graph.action.nodes.create"
      assert jsonrpc["params"]["type"] == "person"
      assert jsonrpc["params"]["data"]["name"] == "Charlie"
      
      # Plug
      plug = Schema.upgrade_to_plug(proto_msg, "CreateNode", TestSchemaAdapter)
      assert plug[:path_params]["path"] == "nodes"
      assert plug[:body_params]["type"] == "person"
      assert plug[:body_params]["data"]["name"] == "Charlie"
      
      # MCP
      mcp = Schema.upgrade_to_mcp(proto_msg, "CreateNode", TestSchemaAdapter)
      assert mcp["type"] == "Node"
      assert mcp["context"]["operation"] == "create"
      assert mcp["data"]["type"] == "person"
      assert mcp["data"]["data"]["name"] == "Charlie"
    end
  end
end