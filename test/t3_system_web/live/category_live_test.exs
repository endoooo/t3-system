defmodule T3SystemWeb.CategoryLiveTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  setup %{conn: conn} do
    superuser = insert(:superuser)
    conn = log_in_user(conn, superuser)
    %{conn: conn}
  end

  describe "Index" do
    test "lists all categories", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/categories")
      |> assert_has("h1", text: "Listing Categories")
      |> assert_has("td", text: category.name)
    end

    test "saves new category", %{conn: conn} do
      conn
      |> visit(~p"/admin/categories/new")
      |> assert_has("h1", text: "New Category")
      |> fill_in("Name", with: "some name")
      |> click_button("Save Category")
      |> assert_has("p", text: "Category created successfully")
      |> assert_has("td", text: "some name")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/admin/categories/new")
      |> fill_in("Name", with: "")
      |> click_button("Save Category")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates category in listing", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/categories/#{category}/edit")
      |> assert_has("h1", text: "Edit Category")
      |> fill_in("Name", with: "some updated name")
      |> click_button("Save Category")
      |> assert_has("p", text: "Category updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes category in listing", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/categories")
      |> click_link("Delete")
      |> refute_has("td", text: category.name)
    end
  end

  describe "Show" do
    test "displays category", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/categories/#{category}")
      |> assert_has("li", text: category.name)
    end

    test "updates category and returns to show", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/categories/#{category}/edit?return_to=show")
      |> assert_has("h1", text: "Edit Category")
      |> fill_in("Name", with: "some updated name")
      |> click_button("Save Category")
      |> assert_has("p", text: "Category updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
