defmodule GraphOS.Core.MCP.GraphExecutableServerTest do
  use ExUnit.Case, async: false
  @moduletag :code_graph

  alias GraphOS.Core.MCP.GraphExecutableServer
  # DefaultServer is not directly used in tests

  # Helper to generate a random session ID
  defp random_session_id, do: "test_session_#{:rand.uniform(1_000_000)}"

  # Helper to simulate an MCP request
  defp send_request(session_id, method, params) do
    request = %{
      "jsonrpc" => "2.0",
      "id" => "request_#{:rand.uniform(1_000_000)}",
      "method" => method,
      "params" => params
    }

    # Process the request through our server
    GraphExecutableServer.handle_message(session_id, request)
  end

  describe "server initialization" do
    test "server starts and initializes correctly" do
      session_id = random_session_id()
      :ok = GraphExecutableServer.start(session_id)

      # Send an initialize request
      params = %{
        "protocolVersion" => "2024-11-05",
        "clientInfo" => %{
          "id" => "test_client",
          "name" => "Test Client"
        }
      }

      {:ok, response} = send_request(session_id, "initialize", params)

      # Check that initialization succeeded
      assert response["result"]["serverInfo"]["name"] == "GraphOS MCP Server"
      assert response["result"]["protocolVersion"] == "2024-11-05"
    end
  end

  describe "tool listing" do
    setup do
      session_id = random_session_id()
      :ok = GraphExecutableServer.start(session_id)

      # Initialize the session
      {:ok, _} =
        send_request(session_id, "initialize", %{
          "protocolVersion" => "2024-11-05",
          "clientInfo" => %{
            "id" => "test_client",
            "name" => "Test Client"
          }
        })

      {:ok, %{session_id: session_id}}
    end

    test "tools/list includes graph tools", %{session_id: session_id} do
      # Request the list of tools
      {:ok, response} = send_request(session_id, "tools/list", %{})

      # Check that our graph tools are included
      tools = response["result"]["tools"]
      tool_names = Enum.map(tools, & &1["name"])

      assert "graph.execute" in tool_names
      assert "graph.query" in tool_names
      assert "graph.create_executable" in tool_names
    end
  end

  describe "executable node operations" do
    setup do
      session_id = random_session_id()
      :ok = GraphExecutableServer.start(session_id)

      # Initialize the session
      {:ok, _} =
        send_request(session_id, "initialize", %{
          "protocolVersion" => "2024-11-05",
          "clientInfo" => %{
            "id" => "test_client",
            "name" => "Test Client"
          }
        })

      {:ok, %{session_id: session_id}}
    end

    test "create and execute an executable node", %{session_id: session_id} do
      # Create an executable node
      {:ok, create_response} =
        send_request(session_id, "tools/call", %{
          "name" => "graph.create_executable",
          "arguments" => %{
            "id" => "test:node",
            "name" => "Test Node",
            "executable_type" => "elixir_code",
            "executable" => "context[:a] + context[:b]"
          }
        })

      # Verify node was created
      assert create_response["result"]["node_id"] == "test:node"

      # Execute the node
      {:ok, execute_response} =
        send_request(session_id, "tools/call", %{
          "name" => "graph.execute",
          "arguments" => %{
            "node_id" => "test:node",
            "context" => %{
              "a" => 20,
              "b" => 22
            }
          }
        })

      # Verify execution result
      assert execute_response["result"] == 42
    end

    test "query for executable nodes", %{session_id: session_id} do
      # Create an executable node first
      {:ok, _} =
        send_request(session_id, "tools/call", %{
          "name" => "graph.create_executable",
          "arguments" => %{
            "id" => "query:test",
            "executable_type" => "elixir_code",
            "executable" => "42"
          }
        })

      # Query for nodes
      {:ok, query_response} =
        send_request(session_id, "tools/call", %{
          "name" => "graph.query",
          "arguments" => %{
            "query" => %{
              "node_properties" => %{
                "executable_type" => "elixir_code"
              }
            }
          }
        })

      # Verify we got at least our node back
      results = query_response["result"]["results"]
      node_ids = Enum.map(results, & &1.id)

      assert "query:test" in node_ids
    end

    test "permission error when executing without permission" do
      # Create a new session with a different user
      session_id = random_session_id()
      :ok = GraphExecutableServer.start(session_id)

      # Initialize with a different user
      {:ok, _} =
        send_request(session_id, "initialize", %{
          "protocolVersion" => "2024-11-05",
          "clientInfo" => %{
            "id" => "unauthorized_user",
            "name" => "Unauthorized User"
          }
        })

      # Create a node in default namespace that the user doesn't have access to
      {:ok, _} =
        send_request(session_id, "tools/call", %{
          "name" => "graph.create_executable",
          "arguments" => %{
            "id" => "restricted:node",
            "executable_type" => "elixir_code",
            "executable" => "42"
          }
        })

      # Create a new session with another user
      other_session = random_session_id()
      :ok = GraphExecutableServer.start(other_session)

      {:ok, _} =
        send_request(other_session, "initialize", %{
          "protocolVersion" => "2024-11-05",
          "clientInfo" => %{
            "id" => "other_user",
            "name" => "Other User"
          }
        })

      # Try to execute the node
      {:error, error} =
        send_request(other_session, "tools/call", %{
          "name" => "graph.execute",
          "arguments" => %{
            "node_id" => "restricted:node"
          }
        })

      # Verify permission denied error
      # Permission denied
      assert error.code == -32003
    end
  end
end
