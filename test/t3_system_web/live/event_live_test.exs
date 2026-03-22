defmodule T3SystemWeb.EventLiveTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  setup %{conn: conn} do
    superuser = insert(:superuser)
    conn = log_in_user(conn, superuser)
    %{conn: conn}
  end

  describe "Index" do
    test "lists all events", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/admin/events")
      |> assert_has("h1", text: "Listing Events")
      |> assert_has("td", text: event.name)
    end

    test "shows category badges for events with categories", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)

      T3System.Repo.insert_all("events_categories", [
        %{event_id: event.id, category_id: category.id}
      ])

      conn
      |> visit(~p"/admin/events")
      |> assert_has("span", text: category.name)
    end

    test "saves new event", %{conn: conn} do
      conn
      |> visit(~p"/admin/events/new")
      |> assert_has("h1", text: "New Event")
      |> fill_in("Nome", with: "some name")
      |> fill_in("Address", with: "some address")
      |> fill_in("Datetime", with: "2026-03-06T22:01")
      |> click_button("Save Event")
      |> assert_has("p", text: "Event created successfully")
      |> assert_has("td", text: "some name")
    end

    test "form renders category checkboxes", %{conn: conn} do
      category = insert(:category)

      conn
      |> visit(~p"/admin/events/new")
      |> assert_has("input[type='checkbox'][aria-label='#{category.name}']")
    end

    test "edit form preselects categories for event", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)

      T3System.Repo.insert_all("events_categories", [
        %{event_id: event.id, category_id: category.id}
      ])

      conn
      |> visit(~p"/admin/events/#{event}/edit")
      |> assert_has("input[type='checkbox'][aria-label='#{category.name}'][checked]")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      conn
      |> visit(~p"/admin/events/new")
      |> fill_in("Nome", with: "")
      |> click_button("Save Event")
      |> assert_has("p", text: "can't be blank")
    end

    test "updates event in listing", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/admin/events/#{event}/edit")
      |> assert_has("h1", text: "Edit Event")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Event")
      |> assert_has("p", text: "Event updated successfully")
      |> assert_has("td", text: "some updated name")
    end

    test "deletes event in listing", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/admin/events")
      |> click_link("Delete")
      |> refute_has("td", text: event.name)
    end
  end

  describe "Show" do
    test "displays event", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/admin/events/#{event}")
      |> assert_has("li", text: event.name)
    end

    test "updates event and returns to show", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/admin/events/#{event}/edit?return_to=show")
      |> assert_has("h1", text: "Edit Event")
      |> fill_in("Nome", with: "some updated name")
      |> click_button("Save Event")
      |> assert_has("p", text: "Event updated successfully")
      |> assert_has("li", text: "some updated name")
    end
  end
end
