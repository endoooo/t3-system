defmodule T3SystemWeb.LeagueLiveTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  setup %{conn: conn} do
    superuser = insert(:superuser)
    conn = log_in_user(conn, superuser)
    %{conn: conn}
  end

  describe "Index" do
    test "lists all leagues", %{conn: conn} do
      league = insert(:league)

      conn
      |> visit(~p"/admin/leagues")
      |> assert_has("h1", text: "Listing Leagues")
      |> assert_has("td", text: league.name)
    end

    test "saves new league", %{conn: conn} do
      conn
      |> visit(~p"/admin/leagues/new")
      |> assert_has("h1", text: "New League")
      |> fill_in("Nome", with: "some name")
      |> click_button("Save League")
      |> assert_has("p", text: "League created successfully")
      |> assert_has("td", text: "some name")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/admin/leagues/new")
      |> fill_in("Nome", with: "")
      |> click_button("Save League")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates league in listing", %{conn: conn} do
      league = insert(:league)

      conn
      |> visit(~p"/admin/leagues/#{league}/edit")
      |> assert_has("h1", text: "Edit League")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save League")
      |> assert_has("p", text: "League updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes league in listing", %{conn: conn} do
      league = insert(:league)

      conn
      |> visit(~p"/admin/leagues")
      |> click_link("Delete")
      |> refute_has("td", text: league.name)
    end
  end

  describe "Show" do
    test "displays league", %{conn: conn} do
      league = insert(:league)

      conn
      |> visit(~p"/admin/leagues/#{league}")
      |> assert_has("li", text: league.name)
    end

    test "updates league and returns to show", %{conn: conn} do
      league = insert(:league)

      conn
      |> visit(~p"/admin/leagues/#{league}/edit?return_to=show")
      |> assert_has("h1", text: "Edit League")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save League")
      |> assert_has("p", text: "League updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
