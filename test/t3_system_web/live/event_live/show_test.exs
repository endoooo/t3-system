defmodule T3SystemWeb.EventLive.ShowTest do
  use T3SystemWeb.ConnCase

  import Phoenix.LiveViewTest
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
      |> assert_has("a", text: "Visão geral")
      |> assert_has("a", text: "Jogos")
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

    test "does not show add registration button for anonymous users", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> refute_has("button", text: "Nova inscrição")
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
      |> refute_has("button", text: "Nova inscrição")
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
      |> assert_has("button", text: "Nova inscrição")
    end

    test "opens new registration modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> assert_has("h2", text: "Nova Inscrição")
    end

    test "cancels new registration modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> click_button("Cancelar")
      |> refute_has("h2", text: "Nova Inscrição")
    end

    test "adds a registration via modal", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      player = insert(:player)
      club = insert(:club)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> unwrap(fn view ->
        Phoenix.LiveViewTest.render_click(view, "select_player", %{
          "id" => to_string(player.id),
          "name" => player.name
        })
      end)
      |> select("Clube", option: club.name)
      |> click_button("Salvar")
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
      |> assert_has("h2", text: "Editar Inscrição")
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
      |> click_link("Jogos")
      |> assert_has("p", text: "No matches yet.")
      |> click_link("Visão geral")
      |> assert_has("select", text: category.name)
    end
  end

  describe "superuser - group player management" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      stage = insert(:stage, event: event, category: category, name: "Groups", order: 1)
      group = insert(:group, stage: stage)

      %{
        conn: log_in_user(conn, superuser),
        event: event,
        category: category,
        stage: stage,
        group: group
      }
    end

    defp stage_url(event, category, stage),
      do: ~p"/events/#{event}?tab=stage-#{stage.id}&category_id=#{category.id}"

    test "opens manage players modal", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage,
      group: group
    } do
      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("h2", text: "Gerenciar jogadores")
      |> assert_has("h2", text: group.name)
    end

    test "shows empty state when group has no players", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage
    } do
      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("p", text: "No players added yet.")
    end

    test "shows existing players in the modal", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage,
      group: group
    } do
      player = insert(:player)
      club = insert(:club)

      registration =
        insert(:registration, event: event, category: category, player: player, club: club)

      add_to_group(group, registration)

      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("li", text: player.name)
    end

    test "closes the modal", %{conn: conn, event: event, category: category, stage: stage} do
      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("h2", text: "Gerenciar jogadores")
      |> click_button("Close")
      |> refute_has("h2", text: "Gerenciar jogadores")
    end

    test "adds a player to the group", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage
    } do
      player = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> select("Add Player", option: "#{player.name} — #{club.name}")
      |> assert_has("li", text: player.name)
    end

    test "adding a player updates the main standings view", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage
    } do
      player = insert(:player)
      club = insert(:club)
      insert(:registration, event: event, category: category, player: player, club: club)

      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> select("Add Player", option: "#{player.name} — #{club.name}")
      |> click_button("Close")
      |> assert_has("td", text: player.name)
    end

    test "removes a player from the group", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage,
      group: group
    } do
      player = insert(:player)
      club = insert(:club)

      registration =
        insert(:registration, event: event, category: category, player: player, club: club)

      add_to_group(group, registration)

      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("li", text: player.name)
      |> click_button("Remove")
      |> refute_has("li", text: player.name)
    end

    test "player already in another group is excluded from the add select", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage,
      group: group
    } do
      group2 = insert(:group, stage: stage)
      player_taken = insert(:player)
      player_free = insert(:player)
      club = insert(:club)

      reg_taken =
        insert(:registration, event: event, category: category, player: player_taken, club: club)

      insert(:registration, event: event, category: category, player: player_free, club: club)
      add_to_group(group2, reg_taken)

      conn
      |> visit(stage_url(event, category, stage))
      |> within("#group-#{group.id}", fn session ->
        click_button(session, "Jogadores")
      end)
      |> refute_has("option", text: player_taken.name)
      |> assert_has("option", text: player_free.name)
    end

    test "generate matches button is disabled with fewer than 2 players", %{
      conn: conn,
      event: event,
      category: category,
      stage: stage
    } do
      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> assert_has("button[disabled]", text: "Gerar")
    end
  end

  describe "table management" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      event = insert(:event)
      %{conn: log_in_user(conn, superuser), event: event}
    end

    test "superuser sees Management tab", %{conn: conn, event: event} do
      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("a", text: "Gestão")
    end

    test "regular user does not see Management tab", %{conn: _conn, event: event} do
      user = insert(:user)

      build_conn()
      |> log_in_user(user)
      |> visit(~p"/events/#{event}")
      |> refute_has("a", text: "Gestão")
    end

    test "can add a table", %{conn: conn, event: event} do
      conn
      |> visit(~p"/events/#{event}?tab=management")
      |> click_button("Adicionar mesa")
      |> fill_in("Nome", with: "Table 1")
      |> click_button("Salvar")
      |> assert_has("li", text: "Table 1")
    end

    test "can edit a table", %{conn: conn, event: event} do
      insert(:table, event: event, name: "Old Name")

      conn
      |> visit(~p"/events/#{event}?tab=management")
      |> assert_has("li", text: "Old Name")
      |> click_button("Edit")
      |> fill_in("Nome", with: "New Name")
      |> click_button("Salvar")
      |> assert_has("li", text: "New Name")
    end

    test "can delete a table", %{conn: conn, event: event} do
      insert(:table, event: event, name: "To Delete")

      conn
      |> visit(~p"/events/#{event}?tab=management")
      |> assert_has("li", text: "To Delete")
      |> click_button("Delete")
      |> refute_has("li", text: "To Delete")
    end
  end

  describe "superuser - matches tab ordering" do
    test "orders matches by stage order, then group position and scheduled_position", %{
      conn: conn
    } do
      superuser = insert(:superuser)
      conn = log_in_user(conn, superuser)

      event = insert(:event)
      category = insert(:category)
      associate_category(event, category)
      club = insert(:club)

      # Stage 2 (group) — should appear second despite being inserted first
      stage2 = insert(:stage, event: event, category: category, name: "Stage 2", order: 2)
      group_s2 = insert(:group, stage: stage2, name: "Group S2", position: 0)

      p_s2 = insert(:player, name: "PlayerStage2A")
      p_s2b = insert(:player, name: "PlayerStage2B")
      reg_s2a = insert(:registration, event: event, category: category, player: p_s2, club: club)
      reg_s2b = insert(:registration, event: event, category: category, player: p_s2b, club: club)
      add_to_group(group_s2, reg_s2a)
      add_to_group(group_s2, reg_s2b)

      insert(:match,
        event: event,
        group: group_s2,
        stage: nil,
        registration1: reg_s2a,
        registration2: reg_s2b,
        scheduled_position: 0
      )

      # Stage 1 (group) — should appear first
      stage1 = insert(:stage, event: event, category: category, name: "Stage 1", order: 1)
      group_b = insert(:group, stage: stage1, name: "Group B", position: 2)
      group_a = insert(:group, stage: stage1, name: "Group A", position: 1)

      p1 = insert(:player, name: "PlayerGA1")
      p2 = insert(:player, name: "PlayerGA2")
      p3 = insert(:player, name: "PlayerGB1")
      p4 = insert(:player, name: "PlayerGB2")
      p5 = insert(:player, name: "PlayerGA3")
      p6 = insert(:player, name: "PlayerGA4")

      reg1 = insert(:registration, event: event, category: category, player: p1, club: club)
      reg2 = insert(:registration, event: event, category: category, player: p2, club: club)
      reg3 = insert(:registration, event: event, category: category, player: p3, club: club)
      reg4 = insert(:registration, event: event, category: category, player: p4, club: club)
      reg5 = insert(:registration, event: event, category: category, player: p5, club: club)
      reg6 = insert(:registration, event: event, category: category, player: p6, club: club)

      add_to_group(group_a, reg1)
      add_to_group(group_a, reg2)
      add_to_group(group_a, reg5)
      add_to_group(group_a, reg6)
      add_to_group(group_b, reg3)
      add_to_group(group_b, reg4)

      # Group A match with scheduled_position 2 (should appear after position 1)
      insert(:match,
        event: event,
        group: group_a,
        stage: nil,
        registration1: reg5,
        registration2: reg6,
        scheduled_position: 2
      )

      # Group A match with scheduled_position 1 (should appear first)
      insert(:match,
        event: event,
        group: group_a,
        stage: nil,
        registration1: reg1,
        registration2: reg2,
        scheduled_position: 1
      )

      # Group B match (should appear after all Group A matches)
      insert(:match,
        event: event,
        group: group_b,
        stage: nil,
        registration1: reg3,
        registration2: reg4,
        scheduled_position: 0
      )

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      # Expected order:
      # 1. Stage 1, Group A, scheduled_position 1 (PlayerGA1 vs PlayerGA2)
      # 2. Stage 1, Group A, scheduled_position 2 (PlayerGA3 vs PlayerGA4)
      # 3. Stage 1, Group B (PlayerGB1 vs PlayerGB2)
      # 4. Stage 2, Group S2 (PlayerStage2A vs PlayerStage2B)
      pos_ga1 = :binary.match(html, "PlayerGA1") |> elem(0)
      pos_ga3 = :binary.match(html, "PlayerGA3") |> elem(0)
      pos_gb1 = :binary.match(html, "PlayerGB1") |> elem(0)
      pos_s2a = :binary.match(html, "PlayerStage2A") |> elem(0)

      assert pos_ga1 < pos_ga3, "Group A pos 1 should appear before Group A pos 2"
      assert pos_ga3 < pos_gb1, "Group A should appear before Group B"
      assert pos_gb1 < pos_s2a, "Stage 1 should appear before Stage 2"
    end
  end

  describe "matches tab player filter" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      conn = log_in_user(conn, superuser)

      event = insert(:event)
      category = insert(:category)
      associate_category(event, category)
      club = insert(:club)

      stage = insert(:stage, event: event, category: category, order: 1)
      group = insert(:group, stage: stage, position: 1)

      alice = insert(:player, name: "Alice")
      bob = insert(:player, name: "Bob")
      carol = insert(:player, name: "Carol")

      reg_alice =
        insert(:registration, event: event, category: category, player: alice, club: club)

      reg_bob = insert(:registration, event: event, category: category, player: bob, club: club)

      reg_carol =
        insert(:registration, event: event, category: category, player: carol, club: club)

      add_to_group(group, reg_alice)
      add_to_group(group, reg_bob)
      add_to_group(group, reg_carol)

      # Alice vs Bob
      insert(:match,
        event: event,
        group: group,
        stage: nil,
        registration1: reg_alice,
        registration2: reg_bob,
        scheduled_position: 1
      )

      # Alice vs Carol
      insert(:match,
        event: event,
        group: group,
        stage: nil,
        registration1: reg_alice,
        registration2: reg_carol,
        scheduled_position: 2
      )

      # Bob vs Carol
      insert(:match,
        event: event,
        group: group,
        stage: nil,
        registration1: reg_bob,
        registration2: reg_carol,
        scheduled_position: 3
      )

      %{
        conn: conn,
        event: event,
        category: category,
        alice: alice,
        bob: bob,
        carol: carol
      }
    end

    test "shows all matches by default", %{conn: conn, event: event, category: category} do
      {:ok, _view, html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Carol"

      match_count = Regex.scan(~r/id="match-\d+"/, html) |> length()
      assert match_count == 3
    end

    test "filters matches by player_id URL param", %{
      conn: conn,
      event: event,
      category: category,
      alice: alice
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event}?tab=matches&category_id=#{category.id}&player_id=#{alice.id}"
        )

      html = render(view)

      # Alice is in: Alice vs Bob (match 1) and Alice vs Carol (match 2)
      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Carol"

      # But Bob vs Carol match should be excluded — count match cards
      match_count = Regex.scan(~r/id="match-\d+"/, html) |> length()
      assert match_count == 2
    end

    test "excludes matches not involving the filtered player", %{
      conn: conn,
      event: event,
      category: category,
      carol: carol
    } do
      {:ok, _view, html} =
        live(
          conn,
          ~p"/events/#{event}?tab=matches&category_id=#{category.id}&player_id=#{carol.id}"
        )

      # Carol is in: Alice vs Carol, Bob vs Carol — 2 of 3 matches
      match_count = Regex.scan(~r/id="match-\d+"/, html) |> length()
      assert match_count == 2
    end

    test "selecting a player navigates with player_id param", %{
      conn: conn,
      event: event,
      category: category,
      alice: alice
    } do
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      view
      |> element("form[phx-change=filter_matches_by_player]")
      |> render_change(%{"player_id" => to_string(alice.id)})

      html = render(view)
      match_count = Regex.scan(~r/id="match-\d+"/, html) |> length()
      assert match_count == 2
    end

    test "selecting 'Filtrar por atleta' clears the filter", %{
      conn: conn,
      event: event,
      category: category,
      alice: alice
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/events/#{event}?tab=matches&category_id=#{category.id}&player_id=#{alice.id}"
        )

      # Should start filtered to 2 matches
      html = render(view)
      assert Regex.scan(~r/id="match-\d+"/, html) |> length() == 2

      view
      |> element("form[phx-change=filter_matches_by_player]")
      |> render_change(%{"player_id" => ""})

      # All 3 matches should be back
      html = render(view)
      assert Regex.scan(~r/id="match-\d+"/, html) |> length() == 3
    end

    test "player filter select lists players from the category", %{
      conn: conn,
      event: event,
      category: category
    } do
      {:ok, _view, html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      assert html =~ "Filtrar por atleta"
      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Carol"
    end
  end

  describe "superuser - matches tab scoring" do
    setup %{conn: conn} do
      superuser = insert(:superuser)
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)
      stage = insert(:stage, event: event, category: category, name: "Groups", order: 1)
      group = insert(:group, stage: stage)

      player1 = insert(:player)
      player2 = insert(:player)
      club = insert(:club)
      reg1 = insert(:registration, event: event, category: category, player: player1, club: club)
      reg2 = insert(:registration, event: event, category: category, player: player2, club: club)
      add_to_group(group, reg1)
      add_to_group(group, reg2)

      match =
        insert(:match,
          event: event,
          group: group,
          stage: nil,
          registration1: reg1,
          registration2: reg2
        )

      %{
        conn: log_in_user(conn, superuser),
        event: event,
        category: category,
        match: match,
        reg1: reg1,
        reg2: reg2,
        player1: player1,
        player2: player2
      }
    end

    test "opens score modal from matches tab and saves scores", %{
      conn: conn,
      event: event,
      category: category,
      match: match,
      reg1: reg1,
      player1: player1,
      player2: player2
    } do
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      # Verify match card is displayed
      html = render(view)
      assert html =~ player1.name
      assert html =~ player2.name

      # Open score modal
      html = view |> element("button", "Resultados") |> render_click()
      assert html =~ "Editar Resultados"

      # Submit scores
      view
      |> form("#score-form", %{
        "sets" => %{
          "0" => %{"score1" => "11", "score2" => "8"}
        },
        "winner_registration_id" => reg1.id
      })
      |> render_submit()

      # Modal should be closed
      refute render(view) =~ "Editar Resultados"

      # Verify scores persisted
      updated_match = T3System.Matches.get_match!(match.id)
      assert updated_match.winner_registration_id == reg1.id
      assert [set] = updated_match.sets
      assert set.score1 == 11
      assert set.score2 == 8
    end

    test "can remove a score set row from the modal", %{
      conn: conn,
      event: event,
      category: category
    } do
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      # Open score modal (default 3 set rows)
      view |> element("button", "Resultados") |> render_click()

      # Should have remove buttons (score_set_count > 1)
      assert has_element?(view, "button[phx-click=remove_score_row]")

      # Remove rows until only 1 remains
      render_click(view, "remove_score_row")
      assert has_element?(view, "button[phx-click=remove_score_row]")

      render_click(view, "remove_score_row")

      # At 1 row, remove buttons should be hidden
      refute has_element?(view, "button[phx-click=remove_score_row]")
    end
  end
end
