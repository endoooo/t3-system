defmodule T3SystemWeb.EventLive.ShowTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  # Helper to associate a category with an event via the join table
  defp associate_category(event, category) do
    T3System.Repo.insert_all("events_categories", [
      %{event_id: event.id, category_id: category.id}
    ])
  end

  defp add_to_group(group, registration) do
    now = DateTime.utc_now(:second)

    T3System.Repo.insert_all("group_registrations", [
      %{
        group_id: group.id,
        registration_id: registration.id,
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  describe "public access" do
    test "displays event header", %{conn: conn} do
      league = insert(:league)
      event = insert(:event, league: league)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("h1", text: event.name)
      |> assert_has("span", text: event.address)
      |> assert_has("span", text: league.name)
    end

    test "displays formatted datetime", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("span", text: "07/03/2026 12:00")
    end

    test "shows tab navigation", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("a", text: "Overview")
      |> assert_has("a", text: "Matches")
      |> assert_has("a", text: "Groups")
      |> assert_has("a", text: "Knockout")
    end

    test "shows category selector when event has categories", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("select", text: category.name)
    end

    test "shows no category message when event has no categories", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("p", text: "No category selected.")
    end

    test "shows registration cards for the default category", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      player = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("h3", text: player.name)
      |> assert_has("p", text: club.name)
    end

    test "non-overview tabs show coming soon placeholder", %{conn: conn} do
      event = insert(:event)

      conn
      |> visit(~p"/events/#{event}?tab=knockout")
      |> assert_has("p", text: "Coming soon.")
    end

    test "does not show add registration button for anonymous users", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> refute_has("button", text: "Add Registration")
    end
  end

  describe "regular user" do
    setup %{conn: conn} do
      user = insert(:user)
      %{conn: log_in_user(conn, user)}
    end

    test "does not show add registration button", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> refute_has("button", text: "Add Registration")
    end

    test "does not show edit or remove buttons on registrations", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      insert(:registration, event: event, category: category)

      conn
      |> visit(~p"/events/#{event}")
      |> refute_has("button", text: "Edit")
      |> refute_has("button", text: "Remove")
    end
  end

  describe "superuser" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      %{conn: log_in_user(conn, superuser)}
    end

    test "shows add registration button", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("button", text: "Add Registration")
    end

    test "opens new registration modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Add Registration")
      |> assert_has("h2", text: "Add Registration")
    end

    test "cancels new registration modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Add Registration")
      |> click_button("Cancel")
      |> refute_has("h2", text: "Add Registration")
    end

    test "adds a registration via modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      player = insert(:player)
      club = insert(:club)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Add Registration")
      |> select("Player", option: player.name)
      |> select("Club", option: club.name)
      |> click_button("Save")
      |> assert_has("h3", text: player.name)
    end

    test "shows edit and remove buttons on registration cards", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      insert(:registration, event: event, category: category)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("button", text: "Edit")
      |> assert_has("button", text: "Remove")
    end

    test "opens edit registration modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      insert(:registration, event: event, category: category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Edit")
      |> assert_has("h2", text: "Edit Registration")
    end

    test "deletes a registration", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      player = insert(:player)
      club = insert(:club)
      associate_category(event, category)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("h3", text: player.name)
      |> click_button("Remove")
      |> refute_has("h3", text: player.name)
    end

    test "switches between categories", %{conn: conn} do
      category1 = insert(:category)
      category2 = insert(:category)
      event = insert(:event)
      associate_category(event, category1)
      associate_category(event, category2)
      player1 = insert(:player)
      player2 = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category1, player: player1, club: club)
      insert(:registration, event: event, category: category2, player: player2, club: club)

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("h3", text: player1.name)
      |> refute_has("h3", text: player2.name)
      |> select("Category", option: category2.name)
      |> assert_has("h3", text: player2.name)
      |> refute_has("h3", text: player1.name)
    end

    test "category filter persists when switching tabs", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_link("Matches")
      |> assert_has("p", text: "No matches yet.")
      |> click_link("Overview")
      |> assert_has("select", text: category.name)
    end
  end

  describe "superuser - group player management" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      group = insert(:group, event: event, category: category)
      %{conn: log_in_user(conn, superuser), event: event, category: category, group: group}
    end

    defp groups_url(event, category),
      do: ~p"/events/#{event}?tab=groups&category_id=#{category.id}"

    test "opens manage players modal", %{
      conn: conn,
      event: event,
      category: category,
      group: group
    } do
      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("h2", text: "Manage Players")
      |> assert_has("h2", text: group.name)
    end

    test "shows empty state when group has no players", %{
      conn: conn,
      event: event,
      category: category
    } do
      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("p", text: "No players added yet.")
    end

    test "shows existing players in the modal", %{
      conn: conn,
      event: event,
      category: category,
      group: group
    } do
      player = insert(:player)
      club = insert(:club)

      registration =
        insert(:registration, event: event, category: category, player: player, club: club)

      add_to_group(group, registration)

      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("li", text: player.name)
    end

    test "closes the modal", %{conn: conn, event: event, category: category} do
      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("h2", text: "Manage Players")
      |> click_button("Close")
      |> refute_has("h2", text: "Manage Players")
    end

    test "adds a player to the group", %{
      conn: conn,
      event: event,
      category: category,
      group: _group
    } do
      player = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> select("Add Player", option: "#{player.name} — #{club.name}")
      |> assert_has("li", text: player.name)
    end

    test "adding a player updates the main standings view", %{
      conn: conn,
      event: event,
      category: category,
      group: _group
    } do
      player = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> select("Add Player", option: "#{player.name} — #{club.name}")
      |> click_button("Close")
      |> assert_has("td", text: player.name)
    end

    test "removes a player from the group", %{
      conn: conn,
      event: event,
      category: category,
      group: group
    } do
      player = insert(:player)
      club = insert(:club)

      registration =
        insert(:registration, event: event, category: category, player: player, club: club)

      add_to_group(group, registration)

      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("li", text: player.name)
      |> click_button("Remove")
      |> refute_has("li", text: player.name)
    end

    test "player already in another group is excluded from the add select", %{
      conn: conn,
      event: event,
      category: category,
      group: group
    } do
      group2 = insert(:group, event: event, category: category)
      player_taken = insert(:player)
      player_free = insert(:player)
      club = insert(:club)

      reg_taken =
        insert(:registration, event: event, category: category, player: player_taken, club: club)

      insert(:registration, event: event, category: category, player: player_free, club: club)
      add_to_group(group2, reg_taken)

      conn
      |> visit(groups_url(event, category))
      |> within("#group-#{group.id}", fn session ->
        click_button(session, "Players")
      end)
      |> refute_has("option", text: player_taken.name)
      |> assert_has("option", text: player_free.name)
    end

    test "generate matches button is disabled with fewer than 2 players", %{
      conn: conn,
      event: event,
      category: category
    } do
      conn
      |> visit(groups_url(event, category))
      |> click_button("Players")
      |> assert_has("button[disabled]", text: "Generate")
    end
  end
end
