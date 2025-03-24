defmodule GraphOS.DevWeb.CodeGraphLiveTest do
  use GraphOS.DevWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "CodeGraph LiveView routes" do
    test "GET /code-graph", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/code-graph")
      assert html =~ "Graph Visualization"
    end

    test "GET /code-graph/file", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/code-graph/file")
      assert html =~ "File Graph Visualization"
    end

    test "GET /code-graph/module", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/code-graph/module")
      assert html =~ "Module Graph Visualization"
    end
  end
end
