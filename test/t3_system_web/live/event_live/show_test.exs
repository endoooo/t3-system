defmodule T3SystemWeb.EventLive.ShowTest do
  use T3SystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import PhoenixTest
  import T3System.Factory

  alias T3System.Accounts.Scope
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Players.Player

  # Helper to associate a category with an event via the join table
  defp associate_category(event, category) do
    T3System.Repo.insert_all("events_categories", [
      %{event_id: event.id, category_id: category.id}
    ])
  end

  # Picks a player in the registration modal's combobox at row `index`, like the
  # `.PlayerCombobox` hook does.
  defp select_pair_player(session, index, player) do
    unwrap(session, fn view ->
      render_click(view, "select_player", %{
        "index" => to_string(index),
        "id" => to_string(player.id),
        "name" => player.name
      })
    end)
  end

  # An event with a doubles category and the pair Ana (Clube A) / Bia (Clube B).
  defp pair_setup do
    category = insert(:category, format: "doubles")
    event = insert(:event)
    associate_category(event, category)
    ana = insert(:player, name: "Ana")
    bia = insert(:player, name: "Bia")
    club_a = insert(:club, name: "Clube A")
    club_b = insert(:club, name: "Clube B")

    registration =
      insert(:doubles_registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player, player: ana, club: club_a, position: 1),
          build(:registration_player, player: bia, club: club_b, position: 2)
        ]
      )

    %{
      event: event,
      category: category,
      registration: registration,
      ana: ana,
      bia: bia,
      club_a: club_a,
      club_b: club_b
    }
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

    test "renders link preview meta tags", %{conn: conn} do
      event = insert(:event, name: "Copa T3")

      html = conn |> get(~p"/events/#{event}") |> html_response(200)

      assert html =~ ~s(<meta property="og:title" content="Copa T3 · T3 System")

      assert html =~
               ~s(<meta property="og:description" content="Acompanhe os jogos e resultados do evento")

      assert html =~
               ~r{<meta property="og:image" content="https?://[^"]+/images/og-image.png"}
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

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: player, club: club)]
      )

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("h3", text: player.name)
      |> assert_has("p", text: club.name)
    end

    test "shows player avatars on registration cards", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      with_picture =
        insert(:player,
          name: "Ana Souza",
          picture_url: "https://res.cloudinary.com/demo/image/upload/v1/players/ana.jpg"
        )

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: with_picture)]
      )

      insert(:registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player,
            player: insert(:player, name: "João da Silva", picture_url: nil)
          )
        ]
      )

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has(
        "#registrations img[src='https://res.cloudinary.com/demo/image/upload/c_fill,g_face,w_80,h_80,f_auto,q_auto/v1/players/ana.jpg']"
      )
      |> assert_has("#registrations span", text: "JS")
      |> assert_has("#registrations button", text: "View picture")
      |> refute_has("#registrations button", text: "JS")
    end

    test "renders a bracket with an unscheduled match", %{conn: conn} do
      event = insert(:event)
      category = insert(:category)
      associate_category(event, category)

      stage =
        insert(:stage,
          event: event,
          category: category,
          type: "bracket",
          rounds: 1,
          name: "Final"
        )

      registration = insert(:registration, event: event, category: category)

      insert(:match,
        event: event,
        stage: stage,
        group: nil,
        round: 1,
        position: 1,
        registration1: registration,
        scheduled_at: nil,
        table: nil
      )

      conn
      |> visit(~p"/events/#{event}?tab=stage-#{stage.id}&category_id=#{category.id}")
      |> assert_has("span",
        text: Player.display_short_name(hd(registration.registration_players).player)
      )
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

    test "keeps new registration modal open with club selected after adding", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      player = insert(:player)
      other_player = insert(:player)
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
      |> assert_has("h2", text: "Nova Inscrição")
      |> assert_has("#player-autocomplete[value='']")
      |> refute_has("el-option", text: player.name)
      |> assert_has("el-option", text: other_player.name)
      |> assert_has("#registration-form select option[selected]", text: club.name)
      |> unwrap(fn view ->
        Phoenix.LiveViewTest.render_click(view, "select_player", %{
          "id" => to_string(other_player.id),
          "name" => other_player.name
        })
      end)
      |> assert_has("#registration-form select option[selected]", text: club.name)
    end

    test "singles modal shows one player + club row", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> assert_has("#registration-form label", text: "Jogador", exact: true)
      |> assert_has("#registration-form label", text: "Clube", exact: true)
      |> refute_has("#registration-form label", text: "Jogador 2")
    end

    test "adds a pair via the doubles modal and keeps both clubs", %{conn: conn} do
      category = insert(:category, format: "doubles")
      event = insert(:event)
      ana = insert(:player, name: "Ana")
      bia = insert(:player, name: "Bia")
      [club_a, club_b] = insert_list(2, :club)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> assert_has("#registration-form label", text: "Jogador 1")
      |> assert_has("#registration-form label", text: "Jogador 2")
      |> select_pair_player(0, ana)
      |> select_pair_player(1, bia)
      |> select("Clube 1", option: club_a.name)
      |> select("Clube 2", option: club_b.name)
      |> click_button("Salvar")
      |> assert_has("#registrations li li:first-child", text: "Ana")
      |> assert_has("#registrations li li:last-child", text: "Bia")
      |> assert_has("#registrations", text: "#{club_a.name} / #{club_b.name}")
      |> assert_has("#flash-info", text: "Ana / Bia")
      |> assert_has("h2", text: "Nova Inscrição")
      |> assert_has("#registration-form select[name$='[0][club_id]'] option[selected]",
        text: club_a.name
      )
      |> assert_has("#registration-form select[name$='[1][club_id]'] option[selected]",
        text: club_b.name
      )
    end

    test "saving a pair with only one player shows a clear error", %{conn: conn} do
      category = insert(:category, format: "doubles")
      event = insert(:event)
      ana = insert(:player, name: "Ana")
      club = insert(:club)
      associate_category(event, category)

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> select_pair_player(0, ana)
      |> select("Clube 1", option: club.name)
      |> click_button("Salvar")
      |> assert_has("#registration-form",
        text: "a doubles registration must have exactly 2 players"
      )
      |> assert_has("h2", text: "Nova Inscrição")
      |> refute_has("#registrations h3", text: "Ana")
    end

    test "the first doubles picker hides the second row's choice", %{conn: conn} do
      category = insert(:category, format: "doubles")
      event = insert(:event)
      associate_category(event, category)
      insert(:player, name: "Ana")
      bia = insert(:player, name: "Bia")

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> assert_has("#player-combobox-0 el-option", text: "Bia")
      |> select_pair_player(1, bia)
      |> refute_has("#player-combobox-0 el-option", text: "Bia")
      |> assert_has("#player-combobox-0 el-option", text: "Ana")
    end

    test "doubles pickers hide registered players and the first row's choice", %{conn: conn} do
      category = insert(:category, format: "doubles")
      event = insert(:event)
      associate_category(event, category)
      existing = insert(:doubles_registration, event: event, category: category)
      [first, partner] = Enum.map(existing.registration_players, & &1.player)
      ana = insert(:player, name: "Ana")
      bia = insert(:player, name: "Bia")

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Nova inscrição")
      |> refute_has("el-option", text: first.name)
      |> refute_has("el-option", text: partner.name)
      |> assert_has("#player-combobox-1 el-option", text: "Ana")
      |> select_pair_player(0, ana)
      |> refute_has("#player-combobox-1 el-option", text: "Ana")
      |> assert_has("#player-combobox-1 el-option", text: "Bia")
      |> assert_has("#player-combobox-0 el-option", text: bia.name)
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

    test "edit modal for a pair shows both players and clubs", %{conn: conn} do
      %{event: event, ana: ana, bia: bia, club_a: club_a, club_b: club_b} = pair_setup()

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Edit")
      |> assert_has("h2", text: "Editar Inscrição")
      |> assert_has("#player-autocomplete[value='#{ana.name}']")
      |> assert_has("#player-autocomplete-1[value='#{bia.name}']")
      |> assert_has("#registration-form select[name$='[0][club_id]'] option[selected]",
        text: club_a.name
      )
      |> assert_has("#registration-form select[name$='[1][club_id]'] option[selected]",
        text: club_b.name
      )
    end

    test "substitutes a partner and changes a club of a pair", %{conn: conn} do
      %{event: event} = pair_setup()
      cris = insert(:player, name: "Cris")
      club_c = insert(:club, name: "Clube C")

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Edit")
      |> select_pair_player(1, cris)
      |> select("Clube 1", option: club_c.name)
      |> click_button("Salvar")
      |> refute_has("h2", text: "Editar Inscrição")
      |> assert_has("#registrations li li:first-child", text: "Ana")
      |> assert_has("#registrations li li:last-child", text: "Cris")
      |> assert_has("#registrations", text: "Clube C / Clube B")
    end

    test "names a pair's shared club once", %{conn: conn} do
      %{event: event, registration: pair} = pair_setup()
      club = insert(:club, name: "Clube Único")

      for registration_player <- pair.registration_players do
        registration_player |> Ecto.Changeset.change(club_id: club.id) |> T3System.Repo.update!()
      end

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("#registrations p", text: "Clube Único", exact: true)
    end

    test "swaps the players of a pair between rows", %{conn: conn} do
      %{event: event, ana: ana, bia: bia} = pair_setup()

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Edit")
      |> select_pair_player(0, bia)
      |> select_pair_player(1, ana)
      |> click_button("Salvar")
      |> assert_has("#registrations li li:first-child", text: "Bia")
      |> assert_has("#registrations li li:last-child", text: "Ana")
    end

    test "edit pickers hide other pairs' players but keep the pair's own", %{conn: conn} do
      %{event: event, category: category, ana: ana, bia: bia, registration: pair} = pair_setup()
      other = insert(:doubles_registration, event: event, category: category)
      [taken, _] = Enum.map(other.registration_players, & &1.player)
      free = insert(:player, name: "Livre")

      conn
      |> visit(~p"/events/#{event}")
      |> within("#registrations-#{pair.id}", &click_button(&1, "Edit"))
      |> refute_has("#registration-form el-option", text: taken.name)
      |> assert_has("#player-combobox-0 el-option", text: ana.name)
      |> assert_has("#player-combobox-0 el-option", text: free.name)
      |> assert_has("#player-combobox-1 el-option", text: bia.name)
      |> assert_has("#player-combobox-1 el-option", text: free.name)
    end

    test "editing a pair rejects the same player twice", %{conn: conn} do
      %{event: event, bia: bia} = pair_setup()

      conn
      |> visit(~p"/events/#{event}")
      |> click_button("Edit")
      |> select_pair_player(0, bia)
      |> click_button("Salvar")
      |> assert_has("#registration-form", text: "a pair must have two different players")
      |> assert_has("#registration-form select[name$='[club_id]']", count: 2)
    end

    test "deletes a pair", %{conn: conn} do
      %{event: event} = pair_setup()

      conn
      |> visit(~p"/events/#{event}")
      |> assert_has("#registrations li li:first-child", text: "Ana")
      |> assert_has("#registrations li li:last-child", text: "Bia")
      |> click_button("Remove")
      |> refute_has("#registrations li li", text: "Ana")
    end

    test "deletes a registration", %{conn: conn} do
      category = insert(:category)
      event = insert(:event)
      player = insert(:player)
      club = insert(:club)
      associate_category(event, category)

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: player, club: club)]
      )

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

      insert(:registration,
        event: event,
        category: category1,
        registration_players: [build(:registration_player, player: player1, club: club)]
      )

      insert(:registration,
        event: event,
        category: category2,
        registration_players: [build(:registration_player, player: player2, club: club)]
      )

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
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: player, club: club)]
        )

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
      |> click_button("#players-modal button", "Close")
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

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: player, club: club)]
      )

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

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: player, club: club)]
      )

      conn
      |> visit(stage_url(event, category, stage))
      |> click_button("Jogadores")
      |> select("Add Player", option: "#{player.name} — #{club.name}")
      |> click_button("#players-modal button", "Close")
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
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: player, club: club)]
        )

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
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: player_taken, club: club)]
        )

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: player_free, club: club)]
      )

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

  describe "management schedule view" do
    setup %{conn: conn} do
      event = insert(:event, datetime: ~U[2026-03-07 12:00:00Z], match_duration_minutes: 20)
      category = insert(:category, name: "Adulto")
      associate_category(event, category)
      stage = insert(:stage, event: event, category: category)
      group = insert(:group, stage: stage, name: "Grupo A")

      match_between = fn name1, name2, attrs ->
        reg1 =
          insert(:registration,
            event: event,
            category: category,
            registration_players: [
              build(:registration_player, player: build(:player, name: name1))
            ]
          )

        reg2 =
          insert(:registration,
            event: event,
            category: category,
            registration_players: [
              build(:registration_player, player: build(:player, name: name2))
            ]
          )

        insert(
          :match,
          [event: event, group: group, registration1: reg1, registration2: reg2] ++ attrs
        )
      end

      %{
        conn: log_in_user(conn, insert(:superuser)),
        event: event,
        table: insert(:table, event: event, name: "Mesa 1"),
        match_between: match_between
      }
    end

    test "is hidden from regular users", %{event: event} do
      build_conn()
      |> log_in_user(insert(:user))
      |> visit(~p"/events/#{event}?tab=management&view=schedule")
      |> refute_has("#schedule-board")
    end

    test "is reachable from the management tab", ctx do
      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management")
      |> click_link("Agenda")
      |> assert_has("#schedule-table-#{ctx.table.id} h3", text: "Mesa 1")
      |> click_link("Voltar")
      |> assert_has("h2", text: "Mesas")
    end

    test "lists table queues and counts unscheduled matches", ctx do
      ctx.match_between.("Alice", "Bruno", [])
      ctx.match_between.("Carla", "Davi", table: ctx.table)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> assert_has("#unscheduled-indicator", text: "1 partida sem mesa")
      |> assert_has("#schedule-list-table-#{ctx.table.id} li", text: "Carla")
      |> refute_has("#schedule-board li", text: "Alice")
    end

    test "assigns an unscheduled match to a table from the indicator", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", [])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> click_button("#unscheduled-indicator", "1 partida sem mesa")
      |> assert_has("#unscheduled-match-#{m2.id}", text: "Adulto · Grupo A")
      |> within("#assign-table-form-#{m2.id}", fn session ->
        select(session, "Mesa", option: "Mesa 1")
      end)
      |> refute_has("#unscheduled-match-#{m2.id}")
      |> assert_has("#schedule-match-#{m1.id}", text: "12:00")
      |> assert_has("#schedule-match-#{m2.id}", text: "12:20")
      |> assert_has("#unscheduled-indicator", text: "0 partidas sem mesa")
    end

    test "adds a match to the end of a table from its column", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", [])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> click_button("#schedule-table-#{ctx.table.id} button", "Adicionar jogo")
      |> assert_has("#unscheduled-modal h2", text: "Adicionar jogo à mesa Mesa 1")
      |> click_button("#unscheduled-match-#{m2.id} button", "Adicionar")
      |> assert_has("#schedule-match-#{m1.id}", text: "12:00")
      |> assert_has("#schedule-match-#{m2.id}", text: "12:20")
    end

    test "removes a pending match from its table", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", table: ctx.table, table_position: 1)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> click_button("#schedule-match-#{m1.id} button", "Remover da mesa")
      |> refute_has("#schedule-match-#{m1.id}")
      |> assert_has("#schedule-match-#{m2.id}", text: "12:00")
      |> assert_has("#unscheduled-indicator", text: "1 partida sem mesa")
    end

    test "dropping matches on a table schedules them one duration apart", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", [])
      m2 = ctx.match_between.("Carla", "Davi", [])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> unwrap(fn view ->
        render_hook(view, "reorder_schedule", %{
          "lists" => [
            %{"table_id" => to_string(ctx.table.id), "match_ids" => ["#{m2.id}", "#{m1.id}"]}
          ]
        })
      end)
      |> assert_has("#schedule-match-#{m2.id}", text: "12:00")
      |> assert_has("#schedule-match-#{m1.id}", text: "12:20")
      |> assert_has("#unscheduled-indicator", text: "0 partidas sem mesa")
    end

    test "changing the match duration recalculates the times", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", table: ctx.table, table_position: 1)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> fill_in("Duração dos jogos (min)", with: "30")
      |> assert_has("#schedule-match-#{m1.id}", text: "12:00")
      |> assert_has("#schedule-match-#{m2.id}", text: "12:30")
    end

    test "finished matches are frozen and their time can be edited", ctx do
      finished =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table,
          scheduled_at: ~U[2026-03-07 12:00:00Z]
        )

      T3System.Repo.update!(
        Ecto.Changeset.change(finished, winner_registration_id: finished.registration1_id)
      )

      pending = ctx.match_between.("Carla", "Davi", table: ctx.table, table_position: 1)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> assert_has("h2", text: "Agenda - Em andamento e próximos")
      |> refute_has("#schedule-match-#{finished.id}")
      |> assert_has("#schedule-match-#{pending.id}[data-match-id]")
      |> click_link("#schedule-list-finished", "Finalizados")
      |> assert_has("h2", text: "Agenda - Finalizados")
      |> refute_has("#schedule-match-#{finished.id}[data-match-id]")
      |> refute_has("#schedule-match-#{pending.id}")
      |> click_button("#schedule-match-#{finished.id} button", "Editar horário")
      |> fill_in("Data e hora", with: "2026-03-07T13:00")
      |> click_button("Salvar")
      |> assert_has("#schedule-match-#{finished.id}", text: "13:00")
      |> click_link("#schedule-list-pending", "Em andamento e próximos")
      |> assert_has("#schedule-match-#{pending.id}", text: "13:20")
    end

    test "the ongoing match time can be edited to reschedule the next ones", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", table: ctx.table, table_position: 1)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> refute_has("#schedule-match-#{m1.id} button", text: "Editar horário")
      |> click_button("#schedule-match-#{m1.id} button[role=switch]", "Em andamento")
      |> click_button("#schedule-match-#{m1.id} button", "Editar horário")
      |> fill_in("Data e hora", with: "2026-03-07T12:10")
      |> click_button("Salvar")
      |> assert_has("#schedule-match-#{m1.id}", text: "12:10")
      |> assert_has("#schedule-match-#{m2.id}", text: "12:30")
      |> refute_has("#schedule-match-#{m2.id} button", text: "Editar horário")
    end
  end

  describe "ongoing matches" do
    setup %{conn: conn} do
      event = insert(:event, datetime: ~U[2026-03-07 12:00:00Z], match_duration_minutes: 20)
      category = insert(:category, name: "Adulto")
      associate_category(event, category)
      stage = insert(:stage, event: event, category: category, name: "Fase 1")
      group = insert(:group, stage: stage, name: "Grupo A")

      match_between = fn name1, name2, attrs ->
        [reg1, reg2] =
          for name <- [name1, name2] do
            insert(:registration,
              event: event,
              category: category,
              registration_players: [
                build(:registration_player, player: build(:player, name: name))
              ]
            )
          end

        insert(
          :match,
          [event: event, group: group, registration1: reg1, registration2: reg2] ++ attrs
        )
      end

      %{
        conn: log_in_user(conn, insert(:superuser)),
        event: event,
        category: category,
        stage: stage,
        table1: insert(:table, event: event, name: "Mesa 1"),
        table2: insert(:table, event: event, name: "Mesa 2"),
        match_between: match_between
      }
    end

    test "only the first pending match of a table can be toggled as ongoing", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table1, table_position: 0)
      m2 = ctx.match_between.("Carla", "Davi", table: ctx.table1, table_position: 1)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> refute_has("#schedule-match-#{m2.id} button[role=switch]")
      |> assert_has("#schedule-match-#{m1.id} button[role=switch][aria-checked=false]")
      |> click_button("#schedule-match-#{m1.id} button[role=switch]", "Em andamento")
      |> assert_has("#schedule-match-#{m1.id} button[role=switch][aria-checked=true]")
      |> click_button("#schedule-match-#{m1.id} button[role=switch]", "Em andamento")
      |> assert_has("#schedule-match-#{m1.id} button[role=switch][aria-checked=false]")
    end

    test "overview lists ongoing and next matches ordered by time, then table", ctx do
      # Mesa 2 runs ahead: its ongoing match started earlier
      ongoing1 =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table1,
          table_position: 0,
          scheduled_at: ~U[2026-03-07 12:20:00Z],
          is_ongoing: true
        )

      next1 =
        ctx.match_between.("Carla", "Davi",
          table: ctx.table1,
          table_position: 1,
          scheduled_at: ~U[2026-03-07 12:40:00Z]
        )

      _later1 =
        ctx.match_between.("Elisa", "Fabio",
          table: ctx.table1,
          table_position: 2,
          scheduled_at: ~U[2026-03-07 13:00:00Z]
        )

      ongoing2 =
        ctx.match_between.("Gabi", "Hugo",
          table: ctx.table2,
          table_position: 0,
          scheduled_at: ~U[2026-03-07 12:00:00Z],
          is_ongoing: true
        )

      next2 =
        ctx.match_between.("Iara", "João",
          table: ctx.table2,
          table_position: 1,
          scheduled_at: ~U[2026-03-07 12:40:00Z]
        )

      _unscheduled = ctx.match_between.("Karen", "Lucas", [])

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=overview")
      |> assert_has("#ongoing-matches h2", text: "Em andamento")
      |> assert_has("#next-matches h2", text: "Próximos jogos")

      {:ok, _view, html} = live(build_conn(), ~p"/events/#{ctx.event}?tab=overview")

      assert card_ids(html, "ongoing-matches") == [ongoing2.id, ongoing1.id]
      assert card_ids(html, "next-matches") == [next1.id, next2.id]
    end

    test "overview lists matches of all categories with their category", ctx do
      ongoing =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table1,
          table_position: 0,
          is_ongoing: true
        )

      other_category = insert(:category, name: "Juvenil")
      associate_category(ctx.event, other_category)
      other_stage = insert(:stage, event: ctx.event, category: other_category)
      other_group = insert(:group, stage: other_stage)

      [reg1, reg2] =
        insert_list(2, :registration, event: ctx.event, category: other_category)

      next =
        insert(:match,
          event: ctx.event,
          group: other_group,
          registration1: reg1,
          registration2: reg2,
          table: ctx.table2,
          table_position: 0
        )

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=overview&category_id=#{ctx.category.id}")
      |> assert_has("#ongoing-matches #match-#{ongoing.id}", text: "Adulto")
      |> assert_has("#next-matches #match-#{next.id}", text: "Juvenil")
    end

    test "overview hides empty sections", ctx do
      ctx.match_between.("Alice", "Bruno", [])

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=overview")
      |> refute_has("#ongoing-matches")
      |> refute_has("#next-matches")
    end

    test "overview shows the first pending match as next when nothing is ongoing", ctx do
      m1 = ctx.match_between.("Alice", "Bruno", table: ctx.table1, table_position: 0)
      _m2 = ctx.match_between.("Carla", "Davi", table: ctx.table1, table_position: 1)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=overview")
      |> refute_has("#ongoing-matches")
      |> assert_has("#next-matches #match-#{m1.id}", text: "Alice")
      |> refute_has("#next-matches", text: "Carla")
    end

    test "matches tab flags ongoing matches", ctx do
      ongoing =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table1,
          table_position: 0,
          is_ongoing: true
        )

      pending = ctx.match_between.("Carla", "Davi", table: ctx.table1, table_position: 1)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches")
      |> assert_has("#match-#{ongoing.id} .sr-only", text: "Em andamento")
      |> refute_has("#match-#{pending.id} .sr-only", text: "Em andamento")
    end

    test "bracket tab flags ongoing matches", ctx do
      stage =
        insert(:stage,
          event: ctx.event,
          category: ctx.category,
          type: "bracket",
          rounds: 1,
          order: 2
        )

      match =
        insert(:match,
          event: ctx.event,
          group: nil,
          stage: stage,
          round: 1,
          position: 1,
          table: ctx.table1,
          is_ongoing: true
        )

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}")
      |> assert_has("#bracket-match-#{match.id} .sr-only", text: "Em andamento")
    end

    test "matches tab views filter ongoing and next matches", ctx do
      ongoing1 =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table1,
          table_position: 0,
          scheduled_at: ~U[2026-03-07 12:20:00Z],
          is_ongoing: true
        )

      next1 =
        ctx.match_between.("Carla", "Davi",
          table: ctx.table1,
          table_position: 1,
          scheduled_at: ~U[2026-03-07 12:40:00Z]
        )

      ongoing2 =
        ctx.match_between.("Gabi", "Hugo",
          table: ctx.table2,
          table_position: 0,
          scheduled_at: ~U[2026-03-07 12:00:00Z],
          is_ongoing: true
        )

      next2 =
        ctx.match_between.("Iara", "João",
          table: ctx.table2,
          table_position: 1,
          scheduled_at: ~U[2026-03-07 12:40:00Z]
        )

      finished =
        ctx.match_between.("Elisa", "Fabio",
          table: ctx.table2,
          table_position: 2,
          scheduled_at: ~U[2026-03-07 13:00:00Z]
        )

      T3System.Repo.update!(
        Ecto.Changeset.change(finished, winner_registration_id: finished.registration1_id)
      )

      unscheduled = ctx.match_between.("Karen", "Lucas", [])

      path = ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}"
      {:ok, view, html} = live(build_conn(), path)

      assert length(card_ids(html, "match-cards")) == 6
      assert unscheduled.id in card_ids(html, "match-cards")

      html = view |> element("#match-filters") |> render_change(%{"view" => "ongoing"})
      assert card_ids(html, "match-cards") == [ongoing2.id, ongoing1.id]

      html = view |> element("#match-filters") |> render_change(%{"view" => "next"})

      assert card_ids(html, "match-cards") == [next1.id, next2.id]
    end

    test "matches tab view combines with the player filter", ctx do
      ongoing =
        ctx.match_between.("Alice", "Bruno",
          table: ctx.table1,
          table_position: 0,
          is_ongoing: true
        )

      _other_ongoing =
        ctx.match_between.("Carla", "Davi",
          table: ctx.table2,
          table_position: 0,
          is_ongoing: true
        )

      alice_id = hd(ongoing.registration1.registration_players).player_id

      {:ok, _view, html} =
        live(
          build_conn(),
          ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}&view=ongoing&player_id=#{alice_id}"
        )

      assert card_ids(html, "match-cards") == [ongoing.id]
    end

    test "matches tab shows an empty message when nothing is ongoing", ctx do
      ctx.match_between.("Alice", "Bruno", table: ctx.table1, table_position: 0)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}&view=ongoing")
      |> assert_has("p", text: "Nenhum jogo em andamento.")
    end
  end

  defp card_ids(html, section_id) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("##{section_id} [id^=match-]")
    |> LazyHTML.attribute("id")
    |> Enum.map(fn "match-" <> id -> String.to_integer(id) end)
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

      reg_s2a =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p_s2, club: club)]
        )

      reg_s2b =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p_s2b, club: club)]
        )

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

      reg1 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p1, club: club)]
        )

      reg2 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p2, club: club)]
        )

      reg3 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p3, club: club)]
        )

      reg4 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p4, club: club)]
        )

      reg5 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p5, club: club)]
        )

      reg6 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: p6, club: club)]
        )

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
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: alice, club: club)]
        )

      reg_bob =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: bob, club: club)]
        )

      reg_carol =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: carol, club: club)]
        )

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

    test "filters by a player in position 2 of a registration", %{
      conn: conn,
      event: event,
      category: category
    } do
      group = insert(:group, stage: insert(:stage, event: event, category: category, order: 2))
      edu = insert(:player, name: "Edu")

      pair =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [
            build(:registration_player, player: build(:player, name: "Dani"), position: 1),
            build(:registration_player, player: edu, position: 2)
          ]
        )

      add_to_group(group, pair)

      other =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [
            build(:registration_player, player: build(:player, name: "Fabi"))
          ]
        )

      add_to_group(group, other)

      insert(:match,
        event: event,
        group: group,
        stage: nil,
        registration1: other,
        registration2: pair,
        scheduled_position: 1
      )

      {:ok, view, html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      assert html =~ ~s(<option value="#{edu.id}">Edu</option>)

      view
      |> element("#match-filters")
      |> render_change(%{"player_id" => to_string(edu.id)})

      html = render(view)
      assert Regex.scan(~r/id="match-\d+"/, html) |> length() == 1
      assert html =~ "Dani / Edu"
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
      |> element("#match-filters")
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
      |> element("#match-filters")
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

    test "player filter lists registered players without matches, from every category, once",
         %{conn: conn, event: event, category: category, alice: alice} do
      other_category = insert(:category, format: "doubles")
      associate_category(event, other_category)
      dora = insert(:player, name: "Dora")

      insert(:registration,
        event: event,
        category: category,
        registration_players: [build(:registration_player, player: dora)]
      )

      insert(:doubles_registration,
        event: event,
        category: other_category,
        registration_players: [
          build(:registration_player, player: alice, position: 1),
          build(:registration_player, player: build(:player, name: "Elis"), position: 2)
        ]
      )

      {:ok, _view, html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      assert html =~ ~s(<option value="#{dora.id}">Dora</option>)
      assert html =~ ">Elis</option>"
      assert Regex.scan(~r/>Alice<\/option>/, html) |> length() == 1
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

      reg1 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: player1, club: club)]
        )

      reg2 =
        insert(:registration,
          event: event,
          category: category,
          registration_players: [build(:registration_player, player: player2, club: club)]
        )

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
      updated_match = Matches.get_match!(match.id)
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
      view |> element("#remove-set-3") |> render_click()
      assert has_element?(view, "button[phx-click=remove_score_row]")

      view |> element("#remove-set-2") |> render_click()

      # At 1 row, remove buttons should be hidden
      refute has_element?(view, "button[phx-click=remove_score_row]")
    end

    test "adding a set row keeps the scores already typed", %{
      conn: conn,
      event: event,
      category: category,
      match: match,
      reg1: reg1
    } do
      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}?tab=matches&category_id=#{category.id}")

      view |> element("button", "Resultados") |> render_click()

      view
      |> form("#score-form", %{
        "sets" => %{"0" => %{"score1" => "11", "score2" => "7"}},
        "winner_registration_id" => reg1.id
      })
      |> render_change()

      view |> element("button", "Adicionar set") |> render_click()

      assert has_element?(view, "#score-1-1[value='11']")
      assert has_element?(view, "#score-1-2[value='7']")
      assert has_element?(view, "#score-4-1")
      assert has_element?(view, "#winner-registration-id option[selected][value='#{reg1.id}']")

      view
      |> form("#score-form", %{
        "sets" => %{"3" => %{"score1" => "11", "score2" => "5"}}
      })
      |> render_submit()

      assert [%{set_number: 1, score1: 11, score2: 7}, %{set_number: 4, score1: 11, score2: 5}] =
               match.id
               |> Matches.get_match!()
               |> Map.fetch!(:sets)
               |> Enum.sort_by(& &1.set_number)
    end
  end

  describe "live updates" do
    setup do
      event = insert(:event)
      category = insert(:category, name: "Adulto")
      associate_category(event, category)
      stage = insert(:stage, event: event, category: category, name: "Fase 1")
      group = insert(:group, stage: stage, name: "Grupo A")
      table = insert(:table, event: event, name: "Mesa 1")

      [reg1, reg2] =
        for name <- ["Alice", "Bruno"] do
          insert(:registration,
            event: event,
            category: category,
            registration_players: [
              build(:registration_player, player: build(:player, name: name))
            ]
          )
        end

      match =
        insert(:match,
          event: event,
          group: group,
          registration1: reg1,
          registration2: reg2,
          table: table,
          table_position: 0
        )

      %{
        scope: Scope.for_user(insert(:superuser)),
        event: event,
        category: category,
        match: match
      }
    end

    test "overview shows a match as ongoing once it is marked elsewhere", ctx do
      {:ok, view, _html} = live(build_conn(), ~p"/events/#{ctx.event}?tab=overview")

      refute has_element?(view, "#ongoing-matches #match-#{ctx.match.id}")

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, ctx.match.id, true)

      assert has_element?(view, "#ongoing-matches #match-#{ctx.match.id}")
    end

    test "refreshing keeps the current tab and filters", ctx do
      {:ok, view, _html} =
        live(
          build_conn(),
          ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}&view=ongoing"
        )

      refute has_element?(view, "#match-#{ctx.match.id}")

      {:ok, _event} =
        Events.update_event(ctx.scope, ctx.event, %{
          "name" => "Copa T3",
          "category_ids" => [to_string(ctx.category.id)]
        })

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, ctx.match.id, true)

      assert has_element?(view, "h1", "Copa T3")
      assert has_element?(view, "#match-#{ctx.match.id}")
      assert has_element?(view, "select option[selected]", "Adulto")
    end
  end

  describe "doubles category" do
    setup %{conn: conn} do
      event = insert(:event, datetime: ~U[2026-03-07 12:00:00Z], match_duration_minutes: 20)
      doubles = insert(:category, name: "Duplas", format: "doubles")
      singles = insert(:category, name: "Simples")
      associate_category(event, doubles)
      associate_category(event, singles)

      bia = insert(:player, name: "Bia Costa")

      pair = fn name1, player2, club1, club2 ->
        insert(:doubles_registration,
          event: event,
          category: doubles,
          registration_players: [
            build(:registration_player,
              player: build(:player, name: name1),
              club: build(:club, name: club1),
              position: 1
            ),
            build(:registration_player,
              player: player2,
              club: build(:club, name: club2),
              position: 2
            )
          ]
        )
      end

      %{
        conn: log_in_user(conn, insert(:superuser)),
        event: event,
        doubles: doubles,
        singles: singles,
        bia: bia,
        ana_bia: pair.("Ana Lima", bia, "Clube A", "Clube B"),
        caio_duda: pair.("Caio Melo", build(:player, name: "Duda Reis"), "Clube C", "Clube D")
      }
    end

    # A match between two registrations in a new group of `category`.
    defp group_match(ctx, category, reg1, reg2, attrs \\ []) do
      stage =
        insert(:stage,
          event: ctx.event,
          category: category,
          order: System.unique_integer([:positive])
        )

      group = insert(:group, stage: stage)
      add_to_group(group, reg1)
      add_to_group(group, reg2)

      insert(
        :match,
        [event: ctx.event, group: group, stage: nil, registration1: reg1, registration2: reg2] ++
          attrs
      )
    end

    test "a pair is added to a group from the picker and shown in the group table", ctx do
      stage = insert(:stage, event: ctx.event, category: ctx.doubles, name: "Grupos")
      group = insert(:group, stage: stage)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.doubles.id}")
      |> click_button("Jogadores")
      |> select("Add Player", option: "Ana Lima — Clube A / Bia Costa — Clube B")
      |> assert_has("#players-modal li", text: "Ana Lima / Bia Costa")
      |> click_button("#players-modal button", "Close")
      |> assert_has("#group-#{group.id} td li:first-child", text: "Ana Lima")
      |> assert_has("#group-#{group.id} td li:last-child", text: "Bia Costa")
      |> assert_has("#group-#{group.id} td button", text: "View picture", count: 2)
    end

    test "the bracket shows pairs with the winner and final-standing highlights", ctx do
      stage =
        insert(:stage,
          event: ctx.event,
          category: ctx.doubles,
          type: "bracket",
          rounds: 1,
          name: "Final"
        )

      T3System.Repo.update!(Ecto.Changeset.change(ctx.ana_bia, final_standing: 1))
      T3System.Repo.update!(Ecto.Changeset.change(ctx.caio_duda, final_standing: 2))

      match =
        insert(:match,
          event: ctx.event,
          stage: stage,
          group: nil,
          round: 1,
          position: 1,
          registration1: ctx.ana_bia,
          registration2: ctx.caio_duda,
          winner_registration_id: ctx.ana_bia.id
        )

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.doubles.id}")
      |> assert_has("#bracket-match-#{match.id} .bg-gold\\/15 .font-bold",
        text: "A. Lima / B. Costa"
      )
      |> assert_has("#bracket-match-#{match.id} .bg-silver\\/20", text: "C. Melo / D. Reis")
      |> assert_has("#bracket-match-#{match.id} [data-tooltip='Ana Lima / Bia Costa']",
        text: "A. Lima / B. Costa"
      )
      |> visit(~p"/events/#{ctx.event}?category_id=#{ctx.doubles.id}")
      |> assert_has("#registrations", text: "Campeão")
      |> assert_has("#registrations", text: "Vice-campeão")
    end

    test "match cards show each player's short name and the full names in the tooltip", ctx do
      ctx.ana_bia.registration_players
      |> Enum.find(&(&1.player.name == "Ana Lima"))
      |> Map.fetch!(:player)
      |> Ecto.Changeset.change(short_name: "Aninha")
      |> T3System.Repo.update!()

      match =
        ctx
        |> group_match(ctx.doubles, ctx.ana_bia, ctx.caio_duda)
        |> Ecto.Changeset.change(is_ongoing: true)
        |> T3System.Repo.update!()

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.doubles.id}")
      |> assert_has("#match-#{match.id} [data-tooltip='Ana Lima / Bia Costa']",
        text: "Aninha / B. Costa"
      )
      |> visit(~p"/events/#{ctx.event}?category_id=#{ctx.doubles.id}")
      |> assert_has("#match-#{match.id}", text: "Aninha / B. Costa")
    end

    test "set scores and the winner are recorded for a doubles match", ctx do
      match = group_match(ctx, ctx.doubles, ctx.ana_bia, ctx.caio_duda)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.doubles.id}")
      |> click_button("#match-#{match.id} button", "Resultados")
      |> assert_has("#score-modal", text: "Ana Lima / Bia Costa")
      |> fill_in("Set 1, P1", with: "11")
      |> fill_in("Set 1, P2", with: "8")
      |> select("Vencedor da partida", option: "Caio Melo / Duda Reis")
      |> click_button("#score-modal button", "Salvar")
      |> refute_has("#score-modal")
      |> assert_has("#match-#{match.id} span.font-bold", text: "C. Melo / D. Reis")
      |> assert_has("#match-#{match.id} [data-tooltip='Caio Melo / Duda Reis']")
      |> assert_has("#match-#{match.id} span", text: "11")

      assert Matches.get_match!(match.id).winner_registration_id == ctx.caio_duda.id
    end

    test "doubles and singles matches share a table on the schedule", ctx do
      table = insert(:table, event: ctx.event, name: "Mesa 1")

      singles_reg = fn name ->
        insert(:registration,
          event: ctx.event,
          category: ctx.singles,
          registration_players: [build(:registration_player, player: build(:player, name: name))]
        )
      end

      doubles_match =
        group_match(ctx, ctx.doubles, ctx.ana_bia, ctx.caio_duda,
          table: table,
          table_position: 0,
          scheduled_at: ~U[2026-03-07 12:00:00Z],
          winner_registration_id: ctx.ana_bia.id
        )

      singles_match =
        group_match(ctx, ctx.singles, singles_reg.("Eva Nunes"), singles_reg.("Gil Dias"),
          table: table,
          table_position: 1
        )

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> assert_has("#schedule-match-#{singles_match.id}", text: "Eva Nunes")
      |> click_link("#schedule-list-finished", "Finalizados")
      |> assert_has("#schedule-match-#{doubles_match.id} p.font-bold",
        text: "Ana Lima / Bia Costa"
      )
      |> assert_has("#schedule-match-#{doubles_match.id} p", text: "Caio Melo / Duda Reis")
    end

    test "the player filter lists every partner once and finds a position-2 player's doubles and singles matches",
         ctx do
      eva_dani =
        insert(:doubles_registration,
          event: ctx.event,
          category: ctx.doubles,
          registration_players: [
            build(:registration_player, player: build(:player, name: "Eva Nunes"), position: 1),
            build(:registration_player, player: build(:player, name: "Dani Rocha"), position: 2)
          ]
        )

      vs_caio = group_match(ctx, ctx.doubles, ctx.caio_duda, ctx.ana_bia)
      vs_eva = group_match(ctx, ctx.doubles, ctx.ana_bia, eva_dani)
      other = group_match(ctx, ctx.doubles, ctx.caio_duda, eva_dani)

      bia_singles =
        insert(:registration,
          event: ctx.event,
          category: ctx.singles,
          registration_players: [build(:registration_player, player: ctx.bia)]
        )

      gil =
        insert(:registration,
          event: ctx.event,
          category: ctx.singles,
          registration_players: [
            build(:registration_player, player: build(:player, name: "Gil Dias"))
          ]
        )

      singles_match = group_match(ctx, ctx.singles, gil, bia_singles)

      session =
        visit(ctx.conn, ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.doubles.id}")

      for name <- ~w(Ana Bia Caio Dani Duda Eva Gil) do
        assert_has(session, "#match-filters option", text: name, count: 1)
      end

      session
      |> unwrap(fn view ->
        view
        |> element("#match-filters")
        |> render_change(%{"player_id" => to_string(ctx.bia.id)})
      end)
      |> assert_has("#match-#{vs_caio.id}", text: "C. Melo / D. Reis")
      |> assert_has("#match-#{vs_eva.id}", text: "A. Lima / B. Costa")
      |> assert_has("#match-#{singles_match.id}", text: "G. Dias")
      |> assert_has("#match-#{singles_match.id}", text: "Simples")
      |> refute_has("#match-#{other.id}")
    end
  end

  describe "team category" do
    setup %{conn: conn} do
      event = insert(:event)
      category = insert(:team_category, name: "Equipes")
      associate_category(event, category)

      %{
        conn: log_in_user(conn, insert(:superuser)),
        event: event,
        category: category,
        players: for(name <- ~w(Ana Bia Caio Duda), do: insert(:player, name: name)),
        clubs: for(name <- ["Clube A", "Clube B", "Clube C"], do: insert(:club, name: name))
      }
    end

    # A team named `name` with `players` (each `{player, club}`) in the setup's category.
    defp insert_team(ctx, name, players) do
      insert(:team,
        event: ctx.event,
        category: ctx.category,
        name: name,
        registration_players:
          for {{player, club}, position} <- Enum.with_index(players, 1) do
            build(:registration_player, player: player, club: club, position: position)
          end
      )
    end

    test "the team modal shows a name and three player rows, with add and remove", ctx do
      ctx.conn
      |> visit(~p"/events/#{ctx.event}")
      |> click_button("Nova inscrição")
      |> assert_has("#registration-form label", text: "Nome da equipe")
      |> assert_has("#registration-form label", text: "Jogador 3")
      |> refute_has("#registration-form label", text: "Jogador 4")
      |> assert_has("#registration-form select[name$='[club_id]']", count: 3)
      |> click_button("Adicionar jogador")
      |> assert_has("#registration-form label", text: "Jogador 4")
      |> assert_has("#registration-form select[name$='[club_id]']", count: 4)
      |> within("#player-row-1", &click_button(&1, "Remover jogador"))
      |> assert_has("#registration-form select[name$='[club_id]']", count: 3)
      |> refute_has("#registration-form label", text: "Jogador 4")
    end

    test "removing a row keeps the other rows' players and clubs", ctx do
      [ana, bia, caio, _] = ctx.players
      [club_a, club_b, club_c] = ctx.clubs

      ctx.conn
      |> visit(~p"/events/#{ctx.event}")
      |> click_button("Nova inscrição")
      |> fill_in("Nome da equipe", with: "AABB")
      |> select_pair_player(0, ana)
      |> select_pair_player(1, bia)
      |> select_pair_player(2, caio)
      |> select("Clube 1", option: club_a.name)
      |> select("Clube 2", option: club_b.name)
      |> select("Clube 3", option: club_c.name)
      |> within("#player-row-1", &click_button(&1, "Remover jogador"))
      |> assert_has("#player-autocomplete[value='Ana']")
      |> assert_has("#player-autocomplete-1[value='Caio']")
      |> assert_has("#registration-form select[name$='[1][club_id]'] option[selected]",
        text: club_c.name
      )
      |> click_button("Salvar")
      |> assert_has("#registrations h3", text: "AABB")
      |> assert_has("#registrations li li", text: "Caio")
      |> refute_has("#registrations li li", text: "Bia")
    end

    test "registers a team and keeps the modal open with its clubs", ctx do
      [ana, bia, caio, _] = ctx.players
      [club_a, club_b, _] = ctx.clubs

      ctx.conn
      |> visit(~p"/events/#{ctx.event}")
      |> click_button("Nova inscrição")
      |> fill_in("Nome da equipe", with: "AABB")
      |> select_pair_player(0, ana)
      |> select_pair_player(1, bia)
      |> select_pair_player(2, caio)
      |> select("Clube 1", option: club_a.name)
      |> select("Clube 2", option: club_a.name)
      |> select("Clube 3", option: club_b.name)
      |> click_button("Salvar")
      |> assert_has("#registrations h3", text: "AABB")
      |> assert_has("#registrations li li", text: "Ana")
      |> assert_has("#registrations li li", text: "Caio")
      |> assert_has("#registrations li li", text: "Clube B")
      |> assert_has("#flash-info", text: "AABB")
      |> assert_has("h2", text: "Nova Inscrição")
      |> refute_has("#registration-form input[name='registration[name]'][value='AABB']")
      |> assert_has("#registration-form select[name$='[2][club_id]'] option[selected]",
        text: club_b.name
      )
    end

    test "saving a team without a name shows an error", ctx do
      [ana | _] = ctx.players
      [club_a | _] = ctx.clubs

      ctx.conn
      |> visit(~p"/events/#{ctx.event}")
      |> click_button("Nova inscrição")
      |> select_pair_player(0, ana)
      |> select("Clube 1", option: club_a.name)
      |> click_button("Salvar")
      |> assert_has("#registration-form", text: "can't be blank")
      |> refute_has("#registrations h3", text: "Ana")
    end

    test "edits a team's name and adds a late player", ctx do
      [ana, bia, caio, duda] = ctx.players
      [club_a, club_b, club_c] = ctx.clubs
      insert_team(ctx, "AABB", [{ana, club_a}, {bia, club_b}, {caio, club_c}])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}")
      |> click_button("Edit")
      |> assert_has("h2", text: "Editar Inscrição")
      |> assert_has("#player-autocomplete-2[value='Caio']")
      |> fill_in("Nome da equipe", with: "AABB Renomeada")
      |> click_button("Adicionar jogador")
      |> select_pair_player(3, duda)
      |> select("Clube 4", option: club_c.name)
      |> click_button("Salvar")
      |> refute_has("h2", text: "Editar Inscrição")
      |> assert_has("#registrations h3", text: "AABB Renomeada")
      |> assert_has("#registrations li li", text: "Duda")
    end

    test "visitors see the team name with its players and clubs", ctx do
      [ana, bia | _] = ctx.players
      [club_a, club_b, _] = ctx.clubs
      insert_team(ctx, "AABB", [{ana, club_a}, {bia, club_b}])

      build_conn()
      |> visit(~p"/events/#{ctx.event}")
      |> assert_has("#registrations h3", text: "AABB")
      |> assert_has("#registrations li li", text: "Ana")
      |> assert_has("#registrations li li", text: "Clube A")
      |> assert_has("#registrations li li", text: "Bia")
      |> assert_has("#registrations li li", text: "Clube B")
    end

    # Two teams ("AABB" and "Clube Y") in a group of the setup's category, with
    # their team match.
    defp team_match_setup(ctx) do
      [ana, bia, caio, duda] = ctx.players
      [club_a, club_b, club_c] = ctx.clubs
      team1 = insert_team(ctx, "AABB", [{ana, club_a}, {bia, club_b}])
      team2 = insert_team(ctx, "Clube Y", [{caio, club_c}, {duda, club_c}])
      stage = insert(:stage, event: ctx.event, category: ctx.category, name: "Grupos")
      group = insert(:group, stage: stage, name: "Grupo A", position: 1)
      add_to_group(group, team1)
      add_to_group(group, team2)

      team_match =
        insert(:team_match,
          event: ctx.event,
          group: group,
          registration1: team1,
          registration2: team2
        )

      # Positions in the team match: Ana A, Bia B (AABB); Caio X, Duda Y (Clube Y)
      for {player, side, position} <- [
            {ana, 1, "A"},
            {bia, 1, "B"},
            {caio, 2, "X"},
            {duda, 2, "Y"}
          ] do
        insert(:team_match_position,
          team_match_id: team_match.id,
          player_id: player.id,
          side: side,
          position: position
        )
      end

      %{team1: team1, team2: team2, stage: stage, group: group, team_match: team_match}
    end

    defp set_winner(team_match, team) do
      {:ok, _} =
        Matches.update_match(Scope.for_user(insert(:superuser)), team_match, %{
          "winner_registration_id" => team.id
        })
    end

    test "group standings list teams by name", ctx do
      %{stage: stage, group: group} = team_match_setup(ctx)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> assert_has("#group-#{group.id} td", text: "AABB")
      |> assert_has("#group-#{group.id} td", text: "Clube Y")
      |> refute_has("#group-#{group.id} td", text: "Ana")
    end

    test "group standings rank teams by wins, then match difference, with its column", ctx do
      %{stage: stage, group: group, team_match: team_match, team1: team1, team2: team2} =
        team_match_setup(ctx)

      eva = insert(:player, name: "Eva")
      team3 = insert_team(ctx, "Equipe Z", [{eva, hd(ctx.clubs)}])
      add_to_group(group, team3)

      # AABB and Clube Y both beat Equipe Z; Clube Y by more matches
      for {team, inner_wins} <- [{team1, [team1, team3]}, {team2, [team2, team2]}] do
        tm =
          insert(:team_match,
            event: ctx.event,
            group: group,
            registration1: team,
            registration2: team3,
            winner_registration_id: team.id
          )

        for w <- inner_wins,
            do: insert(:inner_match, team_match: tm, winner_registration_id: w.id)
      end

      _ = team_match

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> assert_has("#group-#{group.id} th", text: "J")
      |> assert_has("#group-#{group.id} tbody tr:nth-child(1)", text: "Clube Y")
      |> assert_has("#group-#{group.id} tbody tr:nth-child(1) td", text: "+2")
      |> assert_has("#group-#{group.id} tbody tr:nth-child(2)", text: "AABB")
      |> assert_has("#group-#{group.id} tbody tr:nth-child(3) td", text: "-2")
    end

    test "team match cards count the matches inside them", ctx do
      %{team_match: team_match, team1: team1, team2: team2} = team_match_setup(ctx)

      for w <- [team1, team2, team1],
          do: insert(:inner_match, team_match: team_match, winner_registration_id: w.id)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}")
      |> assert_has("#team-match-#{team_match.id}", text: "2 — 1")
    end

    test "the group players modal lists and adds teams by name", ctx do
      %{stage: stage, group: group} = team_match_setup(ctx)
      [ana | _] = ctx.players
      insert_team(ctx, "Equipe Z", [{insert(:player, name: "Eva"), hd(ctx.clubs)}])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> within("#group-#{group.id}", &click_button(&1, "Jogadores"))
      |> assert_has("#players-modal li", text: "AABB")
      |> refute_has("#players-modal li", text: ana.name)
      |> select("Add Player", option: "Equipe Z")
      |> assert_has("#players-modal li", text: "Equipe Z")
    end

    test "the matches tab shows team match cards linking to the team match page", ctx do
      %{team_match: team_match} = team_match_setup(ctx)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}")
      |> assert_has("#team-match-#{team_match.id}", text: "AABB")
      |> assert_has("#team-match-#{team_match.id}", text: "Clube Y")
      |> assert_has("#team-match-#{team_match.id}", text: "0 — 0")
      |> assert_has("#team-match-#{team_match.id}", text: "Grupo A")
      |> click_link("#team-match-#{team_match.id}", "AABB")
      |> assert_path(~p"/events/#{ctx.event}/team-matches/#{team_match}",
        query_params: %{"tab" => "matches", "category_id" => to_string(ctx.category.id)}
      )
    end

    test "a team match card highlights the winner", ctx do
      %{team_match: team_match, team2: team2} = team_match_setup(ctx)
      set_winner(team_match, team2)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}")
      |> assert_has("#team-match-#{team_match.id} .font-bold", text: "Clube Y")
      |> refute_has("#team-match-#{team_match.id} .font-bold", text: "AABB")
    end

    test "the ongoing and next filters use the derived team match status", ctx do
      %{team_match: team_match, team1: team1} = team_match_setup(ctx)
      base = ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}"

      build_conn()
      |> visit(base <> "&view=next")
      |> assert_has("#team-match-#{team_match.id}")
      |> visit(base <> "&view=ongoing")
      |> refute_has("#team-match-#{team_match.id}")

      set_winner(team_match, team1)

      build_conn()
      |> visit(base <> "&view=next")
      |> refute_has("#team-match-#{team_match.id}")
      |> visit(base)
      |> assert_has("#team-match-#{team_match.id}")
    end

    test "the player filter keeps the team matches of the player's team", ctx do
      %{team_match: team_match, group: group, team2: team2} = team_match_setup(ctx)
      eva = insert(:player, name: "Eva")
      team3 = insert_team(ctx, "Equipe Z", [{eva, hd(ctx.clubs)}])
      add_to_group(group, team3)

      other =
        insert(:team_match,
          event: ctx.event,
          group: group,
          registration1: team2,
          registration2: team3
        )

      [ana | _] = ctx.players

      build_conn()
      |> visit(
        ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}&player_id=#{ana.id}"
      )
      |> assert_has("#team-match-#{team_match.id}")
      |> refute_has("#team-match-#{other.id}")
    end

    # A one-round bracket stage ("Final") of the setup's category with the team
    # match "AABB" vs "Clube Y".
    defp bracket_team_match_setup(ctx) do
      [ana, bia, caio, duda] = ctx.players
      [club_a, club_b, club_c] = ctx.clubs
      team1 = insert_team(ctx, "AABB", [{ana, club_a}, {bia, club_b}])
      team2 = insert_team(ctx, "Clube Y", [{caio, club_c}, {duda, club_c}])

      stage =
        insert(:stage,
          event: ctx.event,
          category: ctx.category,
          type: "bracket",
          rounds: 1,
          name: "Final"
        )

      team_match =
        insert(:team_match,
          event: ctx.event,
          stage: stage,
          group: nil,
          round: 1,
          position: 1,
          registration1: team1,
          registration2: team2
        )

      %{team1: team1, team2: team2, stage: stage, team_match: team_match}
    end

    test "bracket slots show team names and the score, linking to the team match page", ctx do
      %{stage: stage, team_match: team_match, team2: team2} = bracket_team_match_setup(ctx)
      set_winner(team_match, team2)
      stage_params = %{"tab" => "stage-#{stage.id}", "category_id" => to_string(ctx.category.id)}

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> assert_has("#bracket-match-#{team_match.id}", text: "AABB")
      |> assert_has("#bracket-match-#{team_match.id} .font-bold", text: "Clube Y")
      |> refute_has("#bracket-match-#{team_match.id}", text: "Ana")
      |> assert_has("#bracket-match-#{team_match.id} .tabular-nums", text: "0", count: 2)
      |> click_link("#bracket-team-match-#{team_match.id}", "AABB")
      |> assert_path(~p"/events/#{ctx.event}/team-matches/#{team_match}",
        query_params: stage_params
      )
      |> click_link("Voltar")
      |> assert_path(~p"/events/#{ctx.event}", query_params: stage_params)
      |> assert_has("#bracket-match-#{team_match.id}", text: "AABB")
    end

    test "superusers assign teams to bracket slots by name, without the score modal", ctx do
      %{stage: stage, team_match: team_match} = bracket_team_match_setup(ctx)
      insert_team(ctx, "Equipe Z", [{insert(:player, name: "Eva"), hd(ctx.clubs)}])

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> refute_has("#bracket-match-#{team_match.id} button", text: "Resultados")
      |> within("#bracket-match-#{team_match.id}", &click_button(&1, "Jogadores"))
      |> assert_has("#slot1-registration-id option", text: "AABB")
      |> assert_has("#slot1-registration-id option", text: "Equipe Z")
      |> refute_has("#slot1-registration-id option", text: "Ana")
      |> select("#slot2-registration-id", "Equipe", option: "Equipe Z")
      |> click_button("#assign-slot-form button", "Salvar")
      |> assert_has("#bracket-match-#{team_match.id}", text: "Equipe Z")
      |> refute_has("#bracket-match-#{team_match.id}", text: "Clube Y")
    end

    test "a bracket team match with matches inside it keeps its teams", ctx do
      %{stage: stage, team_match: team_match} = bracket_team_match_setup(ctx)
      insert_team(ctx, "Equipe Z", [{insert(:player, name: "Eva"), hd(ctx.clubs)}])
      insert_inner_match(team_match, ctx)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=stage-#{stage.id}&category_id=#{ctx.category.id}")
      |> within("#bracket-match-#{team_match.id}", &click_button(&1, "Jogadores"))
      |> select("#slot2-registration-id", "Equipe", option: "Equipe Z")
      |> click_button("#assign-slot-form button", "Salvar")
      |> assert_has("#flash-error",
        text: "Exclua as partidas da disputa antes de trocar a equipe"
      )
      |> assert_has("#bracket-match-#{team_match.id}", text: "Clube Y")
      |> refute_has("#bracket-match-#{team_match.id}", text: "Equipe Z")
    end

    test "the player filter keeps the team matches where the player plays a match inside",
         ctx do
      %{team_match: team_match} = bracket_team_match_setup(ctx)
      # Not (or no longer) in either team, but in the lineup of a match inside
      gabi = insert(:player, name: "Gabi")
      insert_inner_match(team_match, ctx, players1: [gabi.id])

      build_conn()
      |> visit(
        ~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}&player_id=#{gabi.id}"
      )
      |> assert_has("#team-match-#{team_match.id}")
    end

    test "bracket team matches appear in the matches tab", ctx do
      %{team_match: team_match} = bracket_team_match_setup(ctx)

      build_conn()
      |> visit(~p"/events/#{ctx.event}?tab=matches&category_id=#{ctx.category.id}")
      |> assert_has("#team-match-#{team_match.id}", text: "AABB")
      |> assert_has("#team-match-#{team_match.id}", text: "Final")
      |> assert_has("#team-match-#{team_match.id}", text: "0 — 0")
    end

    # A singles match inside the team match: Ana (A) x Caio (X)
    defp insert_inner_match(team_match, ctx, attrs \\ []) do
      [ana, _, caio, _] = ctx.players

      insert(
        :inner_match,
        [
          team_match: team_match,
          players1: [ana.id],
          players2: [caio.id]
        ] ++ attrs
      )
    end

    test "the schedule lists matches inside team matches with their context", ctx do
      %{team_match: team_match} = team_match_setup(ctx)
      table = insert(:table, event: ctx.event, name: "Mesa 1")
      unscheduled = insert_inner_match(team_match, ctx)
      scheduled = insert_inner_match(team_match, ctx, table: table)
      # The pool's category filter shows with more than one category
      associate_category(ctx.event, insert(:category, name: "Adulto"))

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> assert_has("#unscheduled-indicator", text: "1 partida sem mesa")
      |> assert_has("#schedule-match-#{scheduled.id}", text: "Equipes · AABB x Clube Y · A x X")
      |> assert_has("#schedule-match-#{scheduled.id}", text: "Ana")
      |> assert_has("#schedule-match-#{scheduled.id}", text: "Caio")
      |> refute_has("#schedule-match-#{scheduled.id} a")
      |> refute_has("#schedule-match-#{team_match.id}")
      |> click_button("#unscheduled-indicator", "1 partida sem mesa")
      |> assert_has("#unscheduled-match-#{unscheduled.id}", text: "AABB x Clube Y · A x X")
      |> refute_has("#unscheduled-match-#{team_match.id}")
      |> select("Categoria", option: "Equipes")
      |> assert_has("#unscheduled-match-#{unscheduled.id}")
      |> within("#assign-table-form-#{unscheduled.id}", &select(&1, "Mesa", option: "Mesa 1"))
      |> assert_has("#schedule-match-#{unscheduled.id}", text: "12:")
      |> assert_has("#unscheduled-indicator", text: "0 partidas sem mesa")
    end

    test "a match inside a team match can be toggled as ongoing from the schedule", ctx do
      %{team_match: team_match} = team_match_setup(ctx)
      table = insert(:table, event: ctx.event, name: "Mesa 1")
      inner = insert_inner_match(team_match, ctx, table: table)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management&view=schedule")
      |> click_button("#schedule-match-#{inner.id} button[role=switch]", "Em andamento")
      |> assert_has("#schedule-match-#{inner.id} button[role=switch][aria-checked=true]")
    end

    test "the unassigned warning counts matches inside team matches, not team matches", ctx do
      %{team_match: team_match} = team_match_setup(ctx)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management")
      |> refute_has("[role=alert]", text: "sem mesa")

      insert_inner_match(team_match, ctx)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?tab=management")
      |> assert_has("*", text: "1 jogo pendente sem mesa")
    end

    test "the overview shows ongoing and next matches inside team matches with their context",
         ctx do
      %{team_match: team_match} = team_match_setup(ctx)
      table1 = insert(:table, event: ctx.event, name: "Mesa 1")
      table2 = insert(:table, event: ctx.event, name: "Mesa 2")
      ongoing = insert_inner_match(team_match, ctx, table: table1, is_ongoing: true)
      [_, bia, _, duda] = ctx.players

      next =
        insert_inner_match(team_match, ctx,
          table: table2,
          players1: [bia.id],
          players2: [duda.id]
        )

      build_conn()
      |> visit(~p"/events/#{ctx.event}?category_id=#{ctx.category.id}")
      |> refute_has("#ongoing-matches #team-match-#{team_match.id}")
      |> assert_has("#ongoing-matches #match-#{ongoing.id}", text: "AABB x Clube Y · A x X")
      |> assert_has("#ongoing-matches #match-#{ongoing.id}", text: "Ana")
      |> assert_has("#ongoing-matches #match-#{ongoing.id}", text: "Equipes")
      |> assert_has("#next-matches #match-#{next.id}", text: "AABB x Clube Y · B x Y")
      |> click_link("#match-#{next.id} a", "AABB x Clube Y · B x Y")
      |> assert_path(~p"/events/#{ctx.event}/team-matches/#{team_match}",
        query_params: %{"tab" => "overview", "category_id" => to_string(ctx.category.id)}
      )
    end

    test "superusers score a match inside a team match from the overview", ctx do
      %{team_match: team_match} = team_match_setup(ctx)
      table = insert(:table, event: ctx.event, name: "Mesa 1")
      inner = insert_inner_match(team_match, ctx, table: table, is_ongoing: true)

      ctx.conn
      |> visit(~p"/events/#{ctx.event}?category_id=#{ctx.category.id}")
      |> click_button("#match-#{inner.id} button", "Resultados")
      |> assert_has("#score-modal", text: "Ana")
      |> assert_has("#score-modal", text: "Caio")
    end
  end
end
