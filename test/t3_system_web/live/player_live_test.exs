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
      |> visit(~p"/players")
      |> assert_has("h1", text: "Listing Player")
      |> assert_has("td", text: player.name)
    end

    test "saves new player", %{conn: conn} do
      conn
      |> visit(~p"/players/new")
      |> assert_has("h1", text: "New Player")
      |> fill_in("Name", with: "some name")
      |> fill_in("Birthdate", with: "2026-03-06")
      |> fill_in("Picture url", with: "some picture_url")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player created successfully")
      |> assert_has("td", text: "some name")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/players/new")
      |> fill_in("Name", with: "")
      |> click_button("Save Player")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates player in listing", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/players/#{player}/edit")
      |> assert_has("h1", text: "Edit Player")
      |> fill_in("Name", with: "some updated name")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes player in listing", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/players")
      |> click_link("Delete")
      |> refute_has("td", text: player.name)
    end
  end

  describe "Show" do
    test "displays player", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/players/#{player}")
      |> assert_has("li", text: player.name)
    end

    test "updates player and returns to show", %{conn: conn} do
      player = insert(:player)

      conn
      |> visit(~p"/players/#{player}/edit?return_to=show")
      |> assert_has("h1", text: "Edit Player")
      |> fill_in("Name", with: "some updated name")
      |> click_button("Save Player")
      |> assert_has("p", text: "Player updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
