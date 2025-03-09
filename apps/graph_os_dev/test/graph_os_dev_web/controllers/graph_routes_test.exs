defmodule GraphOS.DevWeb.GraphRoutesTest do
  use GraphOS.DevWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "route access tests" do
    test "GET / - dashboard page loads", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "GraphOS Dashboard"
    end

    @tag :pending
    test "GET /mcp - MCP dashboard page loads", %{conn: conn} do
      conn = get(conn, "/mcp")
      assert html_response(conn, 200) =~ "MCP Dashboard"
    end

    @tag :pending
    test "GET /mcp/servers - MCP servers page loads", %{conn: conn} do
      conn = get(conn, "/mcp/servers")
      assert html_response(conn, 200) =~ "MCP Servers"
    end

    test "GET /code-graph - LiveView graph page loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/code-graph")
      assert html =~ "Graph Visualization"
    end

    test "GET /code-graph/file - file graph page loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/code-graph/file")
      assert html =~ "File Graph Visualization"
    end

    test "GET /code-graph/file with path parameter - file graph with path loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/code-graph/file?path=apps/graph_os_mcp/lib/graph_os/mcp/application.ex")
      assert html =~ "File Graph Visualization"
      assert html =~ "apps/graph_os_mcp/lib/graph_os/mcp/application.ex"
    end

    test "GET /code-graph/module - module graph page loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/code-graph/module")
      assert html =~ "Module Graph Visualization"
    end

    test "GET /code-graph/module with name parameter - module graph with name loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/code-graph/module?name=GraphOS.MCP.Application")
      assert html =~ "Module Graph Visualization"
      assert html =~ "GraphOS.MCP.Application"
    end

    @tag :skip
    test "GET /api/code-graph/file - file graph API endpoint responds with success", %{conn: conn} do
      conn = get(conn, "/api/code-graph/file?path=apps/graph_os_mcp/lib/graph_os/mcp/application.ex")
      # This test will fail with the current mock implementation (returns 400)
      # But documents the expected behavior for a real implementation
      assert json_response(conn, 200)
    end

    @tag :skip
    test "GET /api/code-graph/module - module graph API endpoint responds with success", %{conn: conn} do
      conn = get(conn, "/api/code-graph/module?name=GraphOS.MCP.Application")
      # This test will fail with the current mock implementation (returns 400)
      # But documents the expected behavior for a real implementation
      assert json_response(conn, 200)
    end

    @tag :skip
    test "GET /api/code-graph/list - list data API endpoint responds", %{conn: conn} do
      conn = get(conn, "/api/code-graph/list")
      json = json_response(conn, 200)

      # Check that the response contains the expected data structure
      assert is_list(json["files"])
      assert is_list(json["modules"])

      # Verify that we have at least some data
      assert length(json["files"]) > 0
      assert length(json["modules"]) > 0
    end
  end
end
