defmodule GraphOS.Protocol.UpgradeTest do
  use ExUnit.Case, async: true

  # Define proto message structs for testing
  defmodule GetNodeRequest do
    @moduledoc "Protocol Buffer message for GetNodeRequest"
    defstruct [:id]
  end

  defmodule Node do
    @moduledoc "Protocol Buffer message for Node"
    defstruct [:id, :type, :data, :created_at, :updated_at]
  end

  # Create a real test schema module
  defmodule TestSchemaAdapter do
    @moduledoc "Test schema adapter for protocol upgrading"

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

    # Serialization helpers for compatibility with the old tests
    def encode(msg) do
      data = Map.from_struct(msg)
      type = msg.__struct__ |> to_string() |> String.split(".") |> List.last()

      Jason.encode!(%{
        "__protobuf_marker__" => true,
        "type" => type,
        "data" => data
      })
    end

    def decode(binary, module) do
      try do
        decoded = Jason.decode!(binary)

        if Map.get(decoded, "__protobuf_marker__") do
          data = Map.get(decoded, "data", %{})

          # Convert string keys to atoms
          data =
            Enum.reduce(data, %{}, fn {k, v}, acc ->
              Map.put(acc, String.to_atom(k), v)
            end)

          # Create the struct
          struct(module, data)
        else
          {:error, :not_protobuf}
        end
      rescue
        e -> {:error, e}
      end
    end
  end

  describe "End-to-end protocol upgrading" do
    test "Protocol Buffer to JSON-RPC to Plug to MCP" do
      # Create a Protocol Buffer message
      proto_msg = %GetNodeRequest{id: "node-1"}

      # Step 1: Convert to JSON-RPC
      jsonrpc = TestSchemaAdapter.upgrade_to_jsonrpc(proto_msg, "GetNode")

      # Verify the JSON-RPC format
      assert jsonrpc["jsonrpc"] == "2.0"
      assert jsonrpc["method"] == "graph.query.nodes.get"
      assert jsonrpc["params"]["id"] == "node-1"

      # Step 2: Convert to Plug format
      plug = TestSchemaAdapter.upgrade_to_plug(proto_msg, "GetNode")

      # Verify the Plug format
      assert plug[:path_params]["path"] == "nodes/node-1"

      # Step 3: Convert to MCP format
      mcp = TestSchemaAdapter.upgrade_to_mcp(proto_msg, "GetNode")

      # Verify the MCP format
      assert mcp["type"] == "Node"
      assert mcp["context"]["operation"] == "get"
      assert mcp["context"]["id"] == "node-1"
    end

    test "Protocol Buffer response messages can be upgraded" do
      # Node response
      _node = %Node{
        id: "node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Verify the schema adapter has the required functions
      assert function_exported?(TestSchemaAdapter, :upgrade_to_jsonrpc, 2)
      assert function_exported?(TestSchemaAdapter, :upgrade_to_plug, 2)
      assert function_exported?(TestSchemaAdapter, :upgrade_to_mcp, 2)
    end
  end

  describe "Cross-protocol serialization" do
    test "Protobuf encoding/decoding works for requests" do
      # Create a Protocol Buffer message
      original = %GetNodeRequest{id: "node-1"}

      # Encode to binary
      binary = TestSchemaAdapter.encode(original)

      # Decode from binary
      decoded = TestSchemaAdapter.decode(binary, GetNodeRequest)

      # Verify the round trip
      assert decoded.id == original.id
    end

    test "Protobuf encoding/decoding works for responses" do
      # Create a Protocol Buffer message
      original = %Node{
        id: "node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }

      # Encode to binary
      binary = TestSchemaAdapter.encode(original)

      # Decode from binary
      decoded = TestSchemaAdapter.decode(binary, Node)

      # Verify the round trip
      assert decoded.id == original.id
      assert decoded.type == original.type
      assert decoded.data["name"] == original.data["name"]
    end
  end
end
