defmodule GraphOS.DevWeb.DashboardControllerTest do
  use GraphOS.DevWeb.ConnCase

  describe "Dashboard routes" do
    test "GET /api/status", %{conn: conn} do
      conn = get(conn, ~p"/api/status")
      assert json_response(conn, 200)
    end
  end
end
