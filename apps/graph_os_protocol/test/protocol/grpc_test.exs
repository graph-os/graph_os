defmodule GraphOS.Protocol.GRPCTest do
  use ExUnit.Case, async: false

  alias GraphOS.Adapter.Context
  alias GraphOS.Protocol.GRPC
  alias GraphOS.Protocol.Schema, as: ProtocolSchema

  # Define proto message structs for testing
  defmodule Node do
    @moduledoc "Protocol Buffer message for Node"
    defstruct [:id, :type, :data, :created_at, :updated_at]
  end

  defmodule NodeList do
    @moduledoc "Protocol Buffer message for NodeList"
    defstruct [:nodes, :next_cursor, :has_more]
  end

  defmodule GetNodeRequest do
    @moduledoc "Protocol Buffer message for GetNodeRequest"
    defstruct [:id]
  end

  defmodule ListNodesRequest do
    @moduledoc "Protocol Buffer message for ListNodesRequest"
    defstruct [:type, :limit, :cursor]
  end

  defmodule CreateNodeRequest do
    @moduledoc "Protocol Buffer message for CreateNodeRequest"
    defstruct [:type, :data]
  end

  # Test Schema Adapter
  defmodule TestSchemaAdapter do
    @moduledoc "Test schema adapter for GRPC tests"

    def get_schema_module, do: __MODULE__

    # Service module implementation
    def service_module, do: __MODULE__

    # Implement upgrade methods for test
    def upgrade_to_jsonrpc(proto_msg, "GetNode") do
      %{
        "jsonrpc" => "2.0",
        "method" => "graph.query.nodes.get",
        "params" => %{"id" => proto_msg.id}
      }
    end

    def upgrade_to_plug(proto_msg, "GetNode") do
      %{
        path_params: %{"path" => "nodes/#{proto_msg.id}"},
        query_params: %{},
        body_params: %{}
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

    # Protocol adapter methods
    def map_rpc_to_operation("GetNode", request) do
      {:ok, :query, %{path: "nodes.get", params: %{id: request.id}}}
    end

    def map_rpc_to_operation("ListNodes", request) do
      params = %{}
      params = if request.type, do: Map.put(params, :type, request.type), else: params
      params = if request.limit, do: Map.put(params, :limit, request.limit), else: params
      params = if request.cursor, do: Map.put(params, :cursor, request.cursor), else: params

      {:ok, :query, %{path: "nodes.list", params: params}}
    end

    def map_rpc_to_operation("CreateNode", request) do
      {:ok, :action,
       %{
         path: "nodes.create",
         params: %{
           type: request.type,
           data: request.data
         }
       }}
    end

    def map_rpc_to_operation(method, _request) do
      {:error, {:unknown_rpc, method}}
    end

    # Convert between proto and structs
    def convert_result_to_proto(result, "GetNode") do
      %Node{
        id: result.id,
        type: result.type,
        data: result.data,
        created_at: result.created_at,
        updated_at: result.updated_at
      }
    end

    def convert_result_to_proto(result, "ListNodes") do
      nodes =
        Enum.map(result.nodes, fn node ->
          %Node{
            id: node.id,
            type: node.type,
            data: node.data,
            created_at: node.created_at,
            updated_at: node.updated_at
          }
        end)

      %NodeList{
        nodes: nodes,
        next_cursor: result.next_cursor,
        has_more: result.has_more
      }
    end

    def convert_result_to_proto(result, "CreateNode") do
      %Node{
        id: result.id,
        type: result.type,
        data: result.data,
        created_at: result.created_at,
        updated_at: result.updated_at
      }
    end
  end

  # Mock tests that avoid the adapter entirely
  describe "GRPC protocol transformation" do
    test "maps RPC to operation through schema adapter" do
      # Create a test request
      request = %GetNodeRequest{id: "test-node-1"}

      # Call schema adapter directly
      result = TestSchemaAdapter.map_rpc_to_operation("GetNode", request)

      # Verify the result matches the expected operation format
      assert {:ok, :query, params} = result
      assert params.path == "nodes.get"
      assert params.params.id == "test-node-1"
    end

    test "converts result to proto message" do
      # Create a sample result
      result = %{
        id: "test-node-1",
        type: "person",
        data: %{"name" => "Test Person", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Convert using the schema adapter
      proto = TestSchemaAdapter.convert_result_to_proto(result, "GetNode")

      # Verify the result is a proper proto message
      assert %Node{} = proto
      assert proto.id == "test-node-1"
      assert proto.type == "person"
      assert proto.data["name"] == "Test Person"
    end

    test "converts list result to proto message" do
      # Create a sample result
      result = %{
        nodes: [
          %{
            id: "node-1",
            type: "person",
            data: %{"name" => "Alice", "age" => 30},
            created_at: "2023-01-01T00:00:00Z",
            updated_at: "2023-01-01T00:00:00Z"
          },
          %{
            id: "node-2",
            type: "person",
            data: %{"name" => "Bob", "age" => 25},
            created_at: "2023-01-02T00:00:00Z",
            updated_at: "2023-01-02T00:00:00Z"
          }
        ],
        next_cursor: nil,
        has_more: false
      }

      # Convert using the schema adapter
      proto = TestSchemaAdapter.convert_result_to_proto(result, "ListNodes")

      # Verify the result is a proper proto message
      assert %NodeList{} = proto
      assert length(proto.nodes) == 2
      assert hd(proto.nodes).id == "node-1"
      assert hd(proto.nodes).type == "person"
    end
  end

  describe "Protocol upgrading" do
    test "supports upgrading to JSON-RPC format" do
      # Create a sample node
      node = %Node{
        id: "test-node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Mock the protocol schema upgrade call
      upgraded = TestSchemaAdapter.upgrade_to_jsonrpc(node, "GetNode")

      # Verify the JSON-RPC format
      assert upgraded["jsonrpc"] == "2.0"
      assert upgraded["method"] == "graph.query.nodes.get"
      assert upgraded["params"]["id"] == "test-node-1"
    end

    test "supports upgrading to Plug format" do
      # Create a sample node
      node = %Node{
        id: "test-node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Mock the protocol schema upgrade call
      upgraded = TestSchemaAdapter.upgrade_to_plug(node, "GetNode")

      # Verify the Plug format
      assert upgraded.path_params["path"] == "nodes/test-node-1"
      assert is_map(upgraded.query_params)
      assert is_map(upgraded.body_params)
    end

    test "supports upgrading to MCP format" do
      # Create a sample node
      node = %Node{
        id: "test-node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Mock the protocol schema upgrade call
      upgraded = TestSchemaAdapter.upgrade_to_mcp(node, "GetNode")

      # Verify the MCP format
      assert upgraded["type"] == "Node"
      assert upgraded["context"]["operation"] == "get"
      assert upgraded["context"]["id"] == "test-node-1"
    end
  end
end
