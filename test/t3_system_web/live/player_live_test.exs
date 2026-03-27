defmodule T3SystemWeb.PlayerLiveTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  setup %{conn: conn} do
    superuser = insert(:superuser)
    conn = log_in_user(conn, superuser)
    %{conn: conn}
  end

  describe "Index" do
    test "lists all player", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players")
      |> assert_has("h1", text: "Listing Player")
      |> assert_has("td", text: player.name)
    end

    test "saves new player", %{conn: conn} do
      conn
      |> visit(~p"/admin/players/new")
      |> assert_has("h1", text: "New Player")
      |> fill_in("Nome", with: "some name")
      |> fill_in("Birthdate", with: "2026-03-06")
      |> fill_in("Picture url", with: "some picture_url")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player created successfully")
      |> assert_has("td", text: "some name")
    end

    test "saves new player and resets form for another", %{conn: conn} do
      conn
      |> visit(~p"/admin/players/new")
      |> fill_in("Nome", with: "first player")
      |> fill_in("Birthdate", with: "2000-01-01")
      |> click_button("Save and add more")
      |> assert_has("p", text: "Player created successfully")
      |> assert_has("h1", text: "New Player")
      |> fill_in("Nome", with: "second player")
      |> fill_in("Birthdate", with: "2000-02-02")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player created successfully")
      |> assert_has("td", text: "second player")
    end

    test "save and add more shows validation errors on invalid data", %{conn: conn} do
      conn
      |> visit(~p"/admin/players/new")
      |> fill_in("Nome", with: "")
      |> click_button("Save and add more")
      |> assert_has("p", text: "can't be blank")
    end

    test "does not show save and add more button when editing", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players/#{player}/edit")
      |> refute_has("button", text: "Save and add more")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/admin/players/new")
      |> fill_in("Nome", with: "")
      |> click_button("Save Player")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates player in listing", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players/#{player}/edit")
      |> assert_has("h1", text: "Edit Player")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes player in listing", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players")
      |> click_link("Delete")
      |> refute_has("td", text: player.name)
    end
  end

  describe "Show" do
    test "displays player", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players/#{player}")
      |> assert_has("li", text: player.name)
    end

    test "updates player and returns to show", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/admin/players/#{player}/edit?return_to=show")
      |> assert_has("h1", text: "Edit Player")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
