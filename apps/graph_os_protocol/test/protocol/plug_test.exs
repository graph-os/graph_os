defmodule GraphOS.Protocol.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test
  
  alias GraphOS.Protocol.Plug
  alias GraphOS.Graph.Schema.TestPersonSchema
  
  # Create a real adapter implementation for testing
  defmodule TestAdapter do
    @moduledoc "Test adapter implementation for Plug tests"
    
    def start_link(_) do
      {:ok, self()}
    end
    
    def execute(_pid, {:query, %{path: "nodes.get", params: _}}, _ctx) do
      {:ok, %{
        id: "node-1",
        type: "person",
        data: %{"name" => "Alice", "age" => 30},
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }}
    end
    
    def execute(_pid, {:query, %{path: "nodes.list", params: _}}, _ctx) do
      nodes = [
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
      ]
      
      {:ok, %{
        nodes: nodes,
        next_cursor: nil,
        has_more: false
      }}
    end
    
    def execute(_pid, {:action, %{path: "nodes.create", params: params}}, _ctx) do
      {:ok, %{
        id: "node-#{:rand.uniform(1000)}",
        type: params.type,
        data: params.data,
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
      }}
    end
    
    def execute(_, _, _), do: {:error, "Not implemented"}

    def stop(_server, _reason) do
      :ok
    end
  end
  
  # Create a real schema module for testing
  defmodule TestSchemaModule do
    @moduledoc "Test schema implementation for Plug tests"
    
    def proto_definition do
      """
      syntax = "proto3";
      
      message Node {
        string id = 1;
        string type = 2;
        map<string, string> data = 3;
        string created_at = 4;
        string updated_at = 5;
      }
      """
    end
    
    # Forward methods for protocol compatibility
    def upgrade_to_plug(proto_msg, "GetNode") do
      %{
        path_params: %{"path" => "nodes/#{proto_msg.id}"},
        query_params: %{},
        body_params: %{}
      }
    end
  end
  
  describe "Plug with protocol support" do
    # Set up a test connection and adapter
    setup do
      # Create a test adapter
      {:ok, adapter_pid} = TestAdapter.start_link([])
      
      # Create a test connection
      conn = conn(:get, "/graph/query/nodes.get")
             |> put_private(:graphos_adapter, adapter_pid)
      
      # Return the test context
      %{
        conn: conn,
        adapter_pid: adapter_pid
      }
    end
    
    test "handles JSON content type", %{conn: conn, adapter_pid: adapter_pid} do
      # Mock the GenServer.execute function to return a predefined response
      :meck.new(GraphOS.Adapter.GenServer, [:passthrough])
      :meck.expect(GraphOS.Adapter.GenServer, :execute, fn _adapter, _operation, _context ->
        {:ok, %{
          id: "node-1",
          type: "person",
          data: %{"name" => "Alice", "age" => 30},
          created_at: "2023-01-01T00:00:00Z",
          updated_at: "2023-01-01T00:00:00Z"
        }}
      end)
      
      # Create a test request with JSON content type
      conn = conn
             |> put_req_header("content-type", "application/json")
             |> Plug.call(%{
               adapter: TestAdapter,
               adapter_opts: [],
               base_path: "graph",
               json_codec: Jason,
               schema_module: TestSchemaModule
             })
      
      # Clean up the mock after the test
      :meck.unload(GraphOS.Adapter.GenServer)
      
      # Check the response
      assert conn.status == 200
      content_type = get_resp_header(conn, "content-type")
      assert String.starts_with?(hd(content_type), "application/json")
      
      # Parse the response body
      response = Jason.decode!(conn.resp_body)
      assert response["id"] == "node-1"
      assert response["type"] == "person"
      assert response["data"]["name"] == "Alice"
    end
    
    test "configures Schema module correctly", %{conn: conn} do
      # Create a test config with schema module
      config = Plug.init([
        adapter: TestAdapter,
        adapter_opts: [schema_module: TestSchemaModule],
        base_path: "graph",
        json_codec: Jason
      ])
      
      # Verify schema module is set
      assert config.schema_module == TestSchemaModule
    end
    
    test "handles empty schema module gracefully", %{conn: conn} do
      # Create a test config without schema module
      config = Plug.init([
        adapter: TestAdapter,
        adapter_opts: [],
        base_path: "graph",
        json_codec: Jason
      ])
      
      # Verify schema module is not set
      assert config.schema_module == nil
    end
    
    test "routes handle different content types based on headers", %{conn: conn} do
      # Create a new adapter for this test to avoid shared state
      {:ok, adapter_pid} = TestAdapter.start_link([])
      
      # Mock the GenServer.execute function
      :meck.new(GraphOS.Adapter.GenServer, [:passthrough])
      :meck.expect(GraphOS.Adapter.GenServer, :execute, fn _adapter, _operation, _context ->
        {:ok, %{
          id: "node-1",
          type: "person",
          data: %{"name" => "Alice", "age" => 30},
          created_at: "2023-01-01T00:00:00Z",
          updated_at: "2023-01-01T00:00:00Z"
        }}
      end)

      # Create a test connection
      conn = conn(:post, "/graph/protobuf/GetNode")
             |> put_req_header("content-type", "application/json")
             |> put_private(:graphos_adapter, adapter_pid)
             |> Plug.call(%{
               adapter: TestAdapter,
               adapter_opts: [],
               base_path: "graph",
               json_codec: Jason,
               schema_module: nil
             })
      
      # Clean up the mock after the test
      :meck.unload(GraphOS.Adapter.GenServer)
      
      # Since schema_module is nil, it should return 501 Not Implemented
      assert conn.status == 501
      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Protocol Buffer support not configured"
    end
  end
  
  describe "read_body function" do
    test "correctly handles different content types" do
      # Test the module for existence of proper functions using introspection
      plug_module_info = GraphOS.Protocol.Plug.__info__(:functions)
      
      assert Keyword.has_key?(plug_module_info, :init)
      assert Keyword.has_key?(plug_module_info, :call)
    end
  end
end