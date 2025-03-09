defmodule GraphOS.DevWeb.ErrorJSONTest do
  use GraphOS.DevWeb.ConnCase, async: true

  test "renders 404" do
    assert GraphOS.DevWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert GraphOS.DevWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
