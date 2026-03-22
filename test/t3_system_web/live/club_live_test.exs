defmodule T3SystemWeb.ClubLiveTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  setup %{conn: conn} do
    superuser = insert(:superuser)
    conn = log_in_user(conn, superuser)
    %{conn: conn}
  end

  describe "Index" do
    test "lists all clubs", %{conn: conn} do
      club = insert(:club)

      conn
      |> visit(~p"/admin/clubs")
      |> assert_has("h1", text: "Listing Clubs")
      |> assert_has("td", text: club.name)
    end

    test "saves new club", %{conn: conn} do
      conn
      |> visit(~p"/admin/clubs/new")
      |> assert_has("h1", text: "New Club")
      |> fill_in("Nome", with: "some name")
      |> click_button("Save Club")
      |> assert_has("p", text: "Club created successfully")
      |> assert_has("td", text: "some name")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/admin/clubs/new")
      |> fill_in("Nome", with: "")
      |> click_button("Save Club")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates club in listing", %{conn: conn} do
      club = insert(:club)

      conn
      |> visit(~p"/admin/clubs/#{club}/edit")
      |> assert_has("h1", text: "Edit Club")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Club")
      |> assert_has("p", text: "Club updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes club in listing", %{conn: conn} do
      club = insert(:club)

      conn
      |> visit(~p"/admin/clubs")
      |> click_link("Delete")
      |> refute_has("td", text: club.name)
    end
  end

  describe "Show" do
    test "displays club", %{conn: conn} do
      club = insert(:club)

      conn
      |> visit(~p"/admin/clubs/#{club}")
      |> assert_has("li", text: club.name)
    end

    test "updates club and returns to show", %{conn: conn} do
      club = insert(:club)

      conn
      |> visit(~p"/admin/clubs/#{club}/edit?return_to=show")
      |> assert_has("h1", text: "Edit Club")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Club")
      |> assert_has("p", text: "Club updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
