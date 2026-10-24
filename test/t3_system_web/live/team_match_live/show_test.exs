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
