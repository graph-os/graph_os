defmodule GraphOS.DevWeb.PageControllerTest do
  use GraphOS.DevWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "GraphOS Dashboard"
  end

  test "GET /mcp", %{conn: conn} do
    conn = get(conn, ~p"/mcp")
    assert html_response(conn, 200) =~ "MCP"
  end
end
