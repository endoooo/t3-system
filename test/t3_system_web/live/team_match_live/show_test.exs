defmodule T3SystemWeb.TeamMatchLive.ShowTest do
  use T3SystemWeb.ConnCase

  import PhoenixTest
  import T3System.Factory

  alias T3System.Accounts.Scope
  alias T3System.Matches

  # An event with a team category "Equipes", the teams "AABB" (Ana, Bia) and
  # "Clube Y" (Caio, Duda) in "Grupo A" of the stage "Grupos", and their team match.
  setup do
    event = insert(:event)
    category = insert(:team_category, name: "Equipes")

    T3System.Repo.insert_all("events_categories", [
      %{event_id: event.id, category_id: category.id}
    ])

    club_a = insert(:club, name: "Clube A")
    club_y = insert(:club, name: "Clube Y")

    team1 =
      insert(:team,
        event: event,
        category: category,
        name: "AABB",
        registration_players: [
          build(:registration_player, player: build(:player, name: "Ana"), club: club_a),
          build(:registration_player,
            player: build(:player, name: "Bia"),
            club: club_a,
            position: 2
          )
        ]
      )

    team2 =
      insert(:team,
        event: event,
        category: category,
        name: "Clube Y",
        registration_players: [
          build(:registration_player, player: build(:player, name: "Caio"), club: club_y),
          build(:registration_player,
            player: build(:player, name: "Duda"),
            club: club_y,
            position: 2
          )
        ]
      )

    stage = insert(:stage, event: event, category: category, name: "Grupos")
    group = insert(:group, stage: stage, name: "Grupo A")

    team_match =
      insert(:team_match, event: event, group: group, registration1: team1, registration2: team2)

    %{
      event: event,
      category: category,
      team1: team1,
      team2: team2,
      stage: stage,
      team_match: team_match
    }
  end

  defp page_path(ctx, params \\ %{}),
    do: ~p"/events/#{ctx.event}/team-matches/#{ctx.team_match}?#{params}"

  test "shows the header with category, group, teams, score and status", ctx do
    build_conn()
    |> visit(page_path(ctx))
    |> assert_has("#team-match-header", text: "Equipes")
    |> assert_has("#team-match-header", text: "Grupos · Grupo A")
    |> assert_has("#team-match-header", text: "AABB")
    |> assert_has("#team-match-header", text: "Clube Y")
    |> assert_has("#team-match-header", text: "0 — 0")
    |> assert_has("#team-match-header", text: "Pendente")
    |> assert_has("#team-match-matches", text: "Nenhuma partida ainda.")
  end

  test "lists each team's players with their clubs", ctx do
    build_conn()
    |> visit(page_path(ctx))
    |> assert_has("#team-#{ctx.team1.id} h3", text: "AABB")
    |> assert_has("#team-#{ctx.team1.id} li", text: "Ana")
    |> assert_has("#team-#{ctx.team1.id} li", text: "Clube A")
    |> assert_has("#team-#{ctx.team2.id} li", text: "Duda")
    |> refute_has("#team-#{ctx.team2.id} li", text: "Ana")
  end

  test "the back link returns to the event tab it came from", ctx do
    build_conn()
    |> visit(page_path(ctx, %{tab: "matches", category_id: ctx.category.id}))
    |> click_link("Voltar")
    |> assert_path(~p"/events/#{ctx.event}",
      query_params: %{"tab" => "matches", "category_id" => to_string(ctx.category.id)}
    )
  end

  test "the back link defaults to the category's matches tab", ctx do
    build_conn()
    |> visit(page_path(ctx))
    |> click_link("Voltar")
    |> assert_path(~p"/events/#{ctx.event}",
      query_params: %{"tab" => "matches", "category_id" => to_string(ctx.category.id)}
    )
  end

  test "a superuser sets and clears the team match winner", ctx do
    build_conn()
    |> log_in_user(insert(:superuser))
    |> visit(page_path(ctx))
    |> click_button("Resultado")
    |> select("Vencedor", option: "Clube Y")
    |> click_button("Salvar")
    |> refute_has("#team-match-winner-modal")
    |> assert_has("#team-match-header .font-bold", text: "Clube Y")
    |> refute_has("#team-match-header .font-bold", text: "AABB")
    |> assert_has("#team-match-header", text: "Finalizado")
    |> click_button("Resultado")
    |> select("Vencedor", option: "Nenhum")
    |> click_button("Salvar")
    |> refute_has("#team-match-header .font-bold", text: "Clube Y")
    |> assert_has("#team-match-header", text: "Pendente")
  end

  test "visitors and regular users see no actions", ctx do
    build_conn()
    |> visit(page_path(ctx))
    |> refute_has("button", text: "Resultado")

    build_conn()
    |> log_in_user(insert(:user))
    |> visit(page_path(ctx))
    |> refute_has("button", text: "Resultado")
  end

  test "updates live when the team match changes", ctx do
    session = visit(build_conn(), page_path(ctx))

    {:ok, _} =
      Matches.update_match(Scope.for_user(insert(:superuser)), ctx.team_match, %{
        "winner_registration_id" => ctx.team1.id
      })

    session
    |> assert_has("#team-match-header .font-bold", text: "AABB")
    |> assert_has("#team-match-header", text: "Finalizado")
  end

  describe "matches inside the team match" do
    defp player_id(team, name),
      do: Enum.find(team.registration_players, &(&1.player.name == name)).player_id

    defp add_inner(ctx, attrs) do
      insert(:inner_match, Map.put(attrs, :team_match, ctx.team_match))
    end

    test "a superuser adds a singles match with a player of each team", ctx do
      table = insert(:table, event_id: ctx.event.id, event: nil, name: "Mesa 1")

      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> click_button("Adicionar partida")
      |> fill_in("Posição — AABB", with: "A")
      |> fill_in("Posição — Clube Y", with: "X")
      |> select("Jogador 1 — AABB", option: "Bia")
      |> select("Jogador 1 — Clube Y", option: "Duda")
      |> select("Mesa", option: "Mesa 1")
      |> click_button("#inner-match-form button", "Salvar")
      |> refute_has("#inner-match-modal")
      |> refute_has("#team-match-matches", text: "Nenhuma partida ainda.")
      |> assert_has("#team-match-matches", text: "Partida 1")
      |> assert_has("#team-match-matches", text: "A")
      |> assert_has("#team-match-matches", text: "Bia")
      |> assert_has("#team-match-matches", text: "Duda")
      |> assert_has("#team-match-matches", text: table.name)
      |> refute_has("#team-match-matches", text: "Ana")
    end

    test "a superuser adds a doubles match", ctx do
      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> click_button("Adicionar partida")
      |> select("Tipo", option: "Duplas")
      |> fill_in("Posição — AABB", with: "AB")
      |> fill_in("Posição — Clube Y", with: "XY")
      |> select("Jogador 1 — AABB", option: "Ana")
      |> select("Jogador 2 — AABB", option: "Bia")
      |> select("Jogador 1 — Clube Y", option: "Caio")
      |> select("Jogador 2 — Clube Y", option: "Duda")
      |> click_button("#inner-match-form button", "Salvar")
      |> assert_has("#team-match-matches", text: "Ana / Bia")
      |> assert_has("#team-match-matches", text: "Caio / Duda")
      |> assert_has("#team-match-matches", text: "XY")
    end

    # The browser posts untouched inputs as `_unused_` keys (here
    # `inner_match[player_ids1][_unused_0]`), which PhoenixTest doesn't send
    test "switching to doubles with untouched player selects", ctx do
      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> click_button("Adicionar partida")
      |> unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element("#inner-match-form")
        |> Phoenix.LiveViewTest.render_change(%{
          "_target" => ["inner_match", "kind"],
          "inner_match" => %{
            "kind" => "doubles",
            "_unused_position1" => "",
            "position1" => "",
            "player_ids1" => %{"_unused_0" => "", "0" => ""},
            "_unused_position2" => "",
            "position2" => "",
            "player_ids2" => %{"_unused_0" => "", "0" => ""},
            "_unused_table_id" => "",
            "table_id" => ""
          }
        })
      end)
      |> assert_has("label", text: "Jogador 2 — AABB")
      |> assert_has("label", text: "Jogador 2 — Clube Y")
    end

    test "a doubles side needs two different players", ctx do
      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> click_button("Adicionar partida")
      |> select("Tipo", option: "Duplas")
      |> select("Jogador 1 — AABB", option: "Ana")
      |> select("Jogador 2 — AABB", option: "Ana")
      |> select("Jogador 1 — Clube Y", option: "Caio")
      |> select("Jogador 2 — Clube Y", option: "Duda")
      |> click_button("#inner-match-form button", "Salvar")
      |> assert_has("#inner-match-modal", text: "pick different players")
      |> assert_has("#team-match-matches", text: "Nenhuma partida ainda.")
    end

    test "inner matches show in creation order with position labels", ctx do
      add_inner(ctx, %{
        position1: "C",
        position2: "Z",
        players1: [player_id(ctx.team1, "Bia")],
        players2: [player_id(ctx.team2, "Duda")]
      })

      add_inner(ctx, %{
        position1: "A",
        position2: "X",
        players1: [player_id(ctx.team1, "Ana")],
        players2: [player_id(ctx.team2, "Caio")]
      })

      build_conn()
      |> visit(page_path(ctx))
      |> assert_has("#team-match-matches > div > :nth-child(1)", text: "Partida 1")
      |> assert_has("#team-match-matches > div > :nth-child(1)", text: "Bia")
      |> assert_has("#team-match-matches > div > :nth-child(1)", text: "C")
      |> assert_has("#team-match-matches > div > :nth-child(2)", text: "Caio")
    end

    test "a superuser edits and deletes an inner match", ctx do
      inner =
        add_inner(ctx, %{
          position1: "A",
          position2: "X",
          players1: [player_id(ctx.team1, "Ana")],
          players2: [player_id(ctx.team2, "Caio")]
        })

      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> within("#match-#{inner.id}", &click_button(&1, "Editar"))
      |> fill_in("Posição — AABB", with: "B")
      |> select("Jogador 1 — AABB", option: "Bia")
      |> click_button("#inner-match-form button", "Salvar")
      |> assert_has("#match-#{inner.id}", text: "Bia")
      |> refute_has("#match-#{inner.id}", text: "Ana")
      |> within("#match-#{inner.id}", &click_button(&1, "Editar"))
      |> click_button("Excluir")
      |> refute_has("#match-#{inner.id}")
      |> assert_has("#team-match-matches", text: "Nenhuma partida ainda.")
    end

    test "a superuser scores an inner match with Resultados; the header counts it", ctx do
      inner =
        add_inner(ctx, %{
          players1: [player_id(ctx.team1, "Ana")],
          players2: [player_id(ctx.team2, "Caio")]
        })

      build_conn()
      |> log_in_user(insert(:superuser))
      |> visit(page_path(ctx))
      |> within("#match-#{inner.id}", &click_button(&1, "Resultados"))
      |> fill_in("Set 1, P1", with: "11")
      |> fill_in("Set 1, P2", with: "6")
      |> select("Vencedor da partida", option: "Ana")
      |> click_button("#score-form button", "Salvar")
      |> refute_has("#score-modal")
      |> assert_has("#match-#{inner.id}", text: "11")
      |> assert_has("#match-#{inner.id} .font-bold", text: "Ana")
      |> assert_has("#team-match-header", text: "1 — 0")
      |> assert_has("#team-match-header", text: "Em andamento")
    end

    test "visitors see inner matches without actions", ctx do
      inner =
        add_inner(ctx, %{
          players1: [player_id(ctx.team1, "Ana")],
          players2: [player_id(ctx.team2, "Caio")]
        })

      build_conn()
      |> visit(page_path(ctx))
      |> assert_has("#match-#{inner.id}", text: "Ana")
      |> refute_has("button", text: "Adicionar partida")
      |> refute_has("#match-#{inner.id} button")
    end

    test "updates live when an inner match is added", ctx do
      session = visit(build_conn(), page_path(ctx))
      tm = Matches.get_team_match!(ctx.event.id, ctx.team_match.id)

      {:ok, _} =
        Matches.create_inner_match(Scope.for_user(insert(:superuser)), tm, %{
          "kind" => "singles",
          "player_ids1" => [player_id(ctx.team1, "Bia")],
          "player_ids2" => [player_id(ctx.team2, "Duda")]
        })

      assert_has(session, "#team-match-matches", text: "Bia")
    end
  end

  test "404 for a match that isn't a team match of the event", ctx do
    singles_match = insert(:match, event: ctx.event)
    other_event = insert(:event)

    assert_raise Ecto.NoResultsError, fn ->
      visit(build_conn(), ~p"/events/#{ctx.event}/team-matches/#{singles_match}")
    end

    assert_raise Ecto.NoResultsError, fn ->
      visit(build_conn(), ~p"/events/#{other_event}/team-matches/#{ctx.team_match}")
    end
  end
end
