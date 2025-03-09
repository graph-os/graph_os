defmodule GraphOS.MCPTest do
  use ExUnit.Case
  doctest GraphOS.MCP

  alias GraphOS.MCP
  alias GraphOS.MCP.Service.SessionStore

  setup do
    # Create a test session
    session_id = "test_session_#{:rand.uniform(1000)}"

    on_exit(fn ->
      # Clean up the session
      SessionStore.delete_session(session_id)
    end)

    {:ok, %{session_id: session_id}}
  end

  describe "MCP Session Management" do
    test "start_session/2 initializes a new session", %{session_id: session_id} do
      assert {:ok, ^session_id, response} = MCP.start_session(session_id)
      assert is_map(response)
      assert response.protocol_version == "2024-03-01"
      assert response.server_info.name == "GraphOS.MCP"
    end

    test "start_session/0 auto-generates session ID" do
      assert {:ok, session_id, _response} = MCP.start_session()
      assert is_binary(session_id)
      assert String.length(session_id) > 0
    end

    test "list_tools/1 returns available tools", %{session_id: session_id} do
      # First initialize the session
      {:ok, _, _} = MCP.start_session(session_id)

      # Then list tools
      assert {:ok, tools} = MCP.list_tools(session_id)
      assert is_list(tools)

      # Should have at least the default tools
      assert Enum.any?(tools, &(&1.name == "echo"))
      assert Enum.any?(tools, &(&1.name == "graph_query"))
    end

    test "list_tools/1 fails for invalid session" do
      assert {:error, :session_not_found} = MCP.list_tools("nonexistent_session")
    end
  end

  describe "MCP Tool Execution" do
    test "execute_tool/3 executes a tool", %{session_id: session_id} do
      # First initialize the session
      {:ok, _, _} = MCP.start_session(session_id)

      # Execute the echo tool
      assert {:ok, result} = MCP.execute_tool(session_id, "echo", %{"message" => "Hello, World!"})
      assert result.echo == "Hello, World!"
    end

    test "execute_tool/3 fails for invalid session" do
      assert {:error, :session_not_found} = MCP.execute_tool("nonexistent_session", "echo", %{})
    end

    test "execute_tool/3 fails for invalid tool", %{session_id: session_id} do
      # First initialize the session
      {:ok, _, _} = MCP.start_session(session_id)

      # Try to execute a non-existent tool
      assert {:error, :tool_not_found} = MCP.execute_tool(session_id, "nonexistent_tool", %{})
    end
  end

  describe "MCP Tool Registration" do
    test "register_tool/1 adds a new tool", %{session_id: session_id} do
      # First initialize the session
      {:ok, _, _} = MCP.start_session(session_id)

      # Define a custom tool
      tool_spec = %{
        name: "test_tool",
        description: "A test tool",
        parameters: %{
          type: "object",
          properties: %{
            input: %{
              type: "string",
              description: "Input value"
            }
          },
          required: ["input"]
        },
        handler: fn %{"input" => input} -> %{output: String.upcase(input)} end
      }

      # Register the tool
      assert :ok = MCP.register_tool(tool_spec)

      # List tools to verify it was added
      {:ok, tools} = MCP.list_tools(session_id)
      assert Enum.any?(tools, &(&1.name == "test_tool"))

      # Execute the tool
      assert {:ok, result} = MCP.execute_tool(session_id, "test_tool", %{"input" => "hello"})
      assert result.output == "HELLO"
    end
  end
end
