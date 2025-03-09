defmodule GraphOS.DevWeb.MCPControllerTest do
  use GraphOS.DevWeb.ConnCase

  describe "MCP routes" do
    test "GET /mcp/servers", %{conn: conn} do
      conn = get(conn, ~p"/mcp/servers")
      assert html_response(conn, 200) =~ "MCP Servers"
    end

    test "GET /mcp/health", %{conn: conn} do
      conn = get(conn, ~p"/mcp/health")
      assert json_response(conn, 200)
    end
  end
end
