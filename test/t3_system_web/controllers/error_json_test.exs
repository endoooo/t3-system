defmodule T3SystemWeb.ErrorJSONTest do
  use T3SystemWeb.ConnCase, async: true

  test "renders 404" do
    assert T3SystemWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert T3SystemWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
