defmodule T3System.Matches do
  @moduledoc """
  The Matches context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category
  alias T3System.Events
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchPlayer
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration
  alias T3System.Tables
  alias T3System.Tables.Table

  @registration_preload Registration.players_preload()

  # ---------------------------------------------------------------------------
  # Stages
  # ---------------------------------------------------------------------------

  @doc """
  Returns stages for the given event, ordered by order.
  """
  def list_stages_for_event(event_id) do
    Stage
    |> where([s], s.event_id == ^event_id)
    |> order_by([s], s.order)
    |> Repo.all()
  end

  @doc """
  Returns stages for the given event and category, ordered by order,
  with groups and bracket matches preloaded (including registrations).
  """
  def list_stages_for_event_and_category(event_id, category_id, opts \\ []) do
    exclude_byes = Keyword.get(opts, :exclude_byes, false)

    Stage
    |> where([s], s.event_id == ^event_id and s.category_id == ^category_id)
    |> order_by([s], s.order)
    |> Repo.all()
    |> preload_stage_matches(exclude_byes)
  end

  @doc """
  Returns stages of all categories for the given event, with their category,
  groups and bracket matches preloaded (excluding byes).
  """
  def list_stages_with_matches_for_event(event_id) do
    Stage
    |> where([s], s.event_id == ^event_id)
    |> order_by([s], [s.category_id, s.order])
    |> preload(:category)
    |> Repo.all()
    |> preload_stage_matches(true)
  end

  defp preload_stage_matches(stages, exclude_byes) do
    bracket_matches_query =
      if exclude_byes,
        do: from(m in Match, where: not m.is_bye),
        else: from(m in Match)

    Repo.preload(stages,
      groups:
        {from(g in Group, order_by: g.position),
         [
           registrations: @registration_preload,
           matches: [
             :sets,
             :table,
             inner_matches: [:sets, :match_players],
             registration1: @registration_preload,
             registration2: @registration_preload,
             winner: @registration_preload
           ]
         ]},
      matches:
        {bracket_matches_query,
         [
           :sets,
           :table,
           inner_matches: [:sets, :match_players],
           registration1: @registration_preload,
           registration2: @registration_preload,
           winner: @registration_preload
         ]}
    )
  end

  @doc """
  Gets a single stage.

  Raises `Ecto.NoResultsError` if the Stage does not exist.
  """
  def get_stage!(id), do: Repo.get!(Stage, id)

  @doc """
  Creates a stage. Requires a superuser scope.
  When type is "bracket" and rounds is provided, auto-generates bracket matches.
  """
  def create_stage(%Scope{user: %{role: "superuser"}}, attrs) do
    type = attrs["type"] || attrs[:type]
    rounds = attrs["rounds"] || attrs[:rounds]

    result =
      if type == "bracket" and rounds do
        create_bracket_stage(attrs)
      else
        %Stage{}
        |> Stage.changeset(attrs)
        |> Repo.insert()
      end

    broadcast_change(result)
  end

  defp create_bracket_stage(attrs) do
    Repo.transaction(fn ->
      case %Stage{} |> Stage.changeset(attrs) |> Repo.insert() do
        {:ok, stage} ->
          generate_bracket_matches(stage)
          stage

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a stage. Requires a superuser scope.
  """
  def update_stage(%Scope{user: %{role: "superuser"}}, %Stage{} = stage, attrs) do
    stage
    |> Stage.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc """
  Deletes a stage. Requires a superuser scope.
  """
  def delete_stage(%Scope{user: %{role: "superuser"}}, %Stage{} = stage) do
    stage_matches =
      from(m in Match,
        left_join: g in Group,
        on: g.id == m.group_id,
        where: m.stage_id == ^stage.id or g.stage_id == ^stage.id
      )

    with_tables_rescheduled(stage.event_id, stage_matches, fn -> Repo.delete(stage) end)
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stage changes.
  """
  def change_stage(%Stage{} = stage, attrs \\ %{}) do
    Stage.changeset(stage, attrs)
  end

  @doc """
  Reconfigures a bracket stage by updating rounds and regenerating matches.
  Deletes existing bracket matches first. Requires a superuser scope.
  """
  def reconfigure_stage_bracket(
        %Scope{user: %{role: "superuser"}},
        %Stage{type: "bracket"} = stage,
        rounds
      ) do
    stage_matches = from(m in Match, where: m.stage_id == ^stage.id)

    Repo.transaction(fn ->
      with_tables_rescheduled(stage.event_id, stage_matches, fn ->
        Repo.delete_all(stage_matches)
      end)

      case stage |> Stage.changeset(%{rounds: rounds}) |> Repo.update() do
        {:ok, stage} ->
          generate_bracket_matches(stage)
          stage

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> broadcast_change()
  end

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of groups for the given event (through stages).
  """
  def list_groups_for_event(event_id) do
    Group
    |> join(:inner, [g], s in Stage, on: g.stage_id == s.id)
    |> where([g, s], s.event_id == ^event_id)
    |> order_by([g], g.position)
    |> Repo.all()
  end

  @doc """
  Returns groups for the given event and category (through stages),
  with members and matches preloaded for standings computation.
  """
  def list_groups_for_event_and_category(event_id, category_id) do
    Group
    |> join(:inner, [g], s in Stage, on: g.stage_id == s.id)
    |> where([g, s], s.event_id == ^event_id and s.category_id == ^category_id)
    |> order_by([g], g.position)
    |> Repo.all()
    |> Repo.preload(
      registrations: @registration_preload,
      matches: [
        :sets,
        inner_matches: [:sets, :match_players],
        registration1: @registration_preload,
        registration2: @registration_preload,
        winner: @registration_preload
      ]
    )
  end

  @doc """
  Returns a group with its registrations (including player and club) preloaded.
  """
  def get_group_with_registrations!(id) do
    Repo.get!(Group, id) |> Repo.preload([:matches, registrations: @registration_preload])
  end

  @doc """
  Adds a registration to a group. Requires a superuser scope.
  """
  def add_registration_to_group(%Scope{user: %{role: "superuser"}}, group_id, registration_id) do
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      "group_registrations",
      [
        %{
          group_id: group_id,
          registration_id: registration_id,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing
    )

    broadcast_group_change(group_id)
    :ok
  end

  @doc """
  Removes a registration from a group and deletes their matches in that group.
  Requires a superuser scope.
  """
  def remove_registration_from_group(
        %Scope{user: %{role: "superuser"}},
        group_id,
        registration_id
      ) do
    Repo.transaction(fn ->
      from(m in Match,
        where:
          m.group_id == ^group_id and
            (m.registration1_id == ^registration_id or m.registration2_id == ^registration_id)
      )
      |> Repo.delete_all()

      from(gr in "group_registrations",
        where: gr.group_id == ^group_id and gr.registration_id == ^registration_id
      )
      |> Repo.delete_all()
    end)

    broadcast_group_change(group_id)
    :ok
  end

  @doc """
  Generates round-robin matches for all members of a group.
  Deletes any existing matches first. Requires a superuser scope.
  Returns `{:ok, match_count}`.
  """
  def generate_group_matches(%Scope{user: %{role: "superuser"}}, %Group{} = group) do
    group = Repo.preload(group, [:registrations, :stage])
    registrations = group.registrations

    pairs =
      for {r1, i} <- Enum.with_index(registrations),
          {r2, j} <- Enum.with_index(registrations),
          i < j,
          do: {r1, r2}

    result =
      Repo.transaction(fn ->
        group_matches = from(m in Match, where: m.group_id == ^group.id)

        with_tables_rescheduled(group.stage.event_id, group_matches, fn ->
          Repo.delete_all(group_matches)
        end)

        {count, _} = Repo.insert_all(Match, build_match_rows(pairs, group))
        count
      end)

    Events.broadcast_event_updated(group.stage.event_id)
    result
  end

  defp build_match_rows([], _group), do: []

  defp build_match_rows(pairs, group) do
    now = DateTime.utc_now(:second)
    event_id = group.stage.event_id

    Enum.map(pairs, fn {r1, r2} ->
      %{
        event_id: event_id,
        group_id: group.id,
        registration1_id: r1.id,
        registration2_id: r2.id,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  @doc """
  Computes standings for a group from its preloaded registrations and matches.

  Returns a list of maps with keys: registration, played, won, lost,
  match_diff, set_diff, point_diff, rank, qualified. Ranked by wins, then set
  difference, then point difference.

  With `team: true` (a team category), the group's matches are team matches
  with their inner matches (and sets) preloaded: wins count team matches, and
  the tiebreaks are inner match difference (`match_diff`), then set and point
  difference, all counted from the inner matches. Otherwise `match_diff` is 0.
  """
  def compute_group_standings(%Group{matches: matches} = group, opts \\ []) do
    qualifies_count = group.qualifies_count
    team? = Keyword.get(opts, :team, false)

    valid_matches =
      Enum.filter(matches, fn m ->
        is_struct(m.registration1, Registration) and is_struct(m.registration2, Registration)
      end)

    all_registrations =
      case group.registrations do
        %Ecto.Association.NotLoaded{} ->
          valid_matches
          |> Enum.flat_map(fn m -> [m.registration1, m.registration2] end)
          |> Enum.uniq_by(& &1.id)

        regs ->
          regs
      end

    stats =
      Enum.map(all_registrations, fn reg ->
        my_matches =
          Enum.filter(valid_matches, fn m ->
            m.registration1_id == reg.id or m.registration2_id == reg.id
          end)

        completed = Enum.filter(my_matches, fn m -> not is_nil(m.winner_registration_id) end)
        won = Enum.count(completed, fn m -> m.winner_registration_id == reg.id end)
        played = length(completed)
        lost = played - won

        # Tiebreaks come from the matches played: inner matches for teams
        scored_matches =
          if team?, do: Enum.flat_map(my_matches, & &1.inner_matches), else: my_matches

        {sets_won, sets_lost, pts_won, pts_lost} =
          Enum.reduce(scored_matches, {0, 0, 0, 0}, &accumulate_set_stats(&1, reg.id, &2))

        match_diff =
          if team?,
            do:
              Enum.count(scored_matches, &(&1.winner_registration_id == reg.id)) -
                Enum.count(scored_matches, &(&1.winner_registration_id not in [nil, reg.id])),
            else: 0

        %{
          registration: reg,
          played: played,
          won: won,
          lost: lost,
          match_diff: match_diff,
          set_diff: sets_won - sets_lost,
          point_diff: pts_won - pts_lost
        }
      end)

    stats
    |> Enum.sort_by(fn s -> {-s.won, -s.match_diff, -s.set_diff, -s.point_diff} end)
    |> Enum.with_index(1)
    |> Enum.map(fn {s, rank} ->
      Map.merge(s, %{rank: rank, qualified: group.is_finished and rank <= qualifies_count})
    end)
  end

  defp accumulate_set_stats(m, reg_id, {sw, sl, pw, pl}) do
    sw2 = Enum.count(m.sets, &(&1.winner_registration_id == reg_id))

    sl2 =
      Enum.count(m.sets, fn s ->
        not is_nil(s.winner_registration_id) and s.winner_registration_id != reg_id
      end)

    {my_scores, opp_scores} =
      if m.registration1_id == reg_id do
        {Enum.map(m.sets, & &1.score1), Enum.map(m.sets, & &1.score2)}
      else
        {Enum.map(m.sets, & &1.score2), Enum.map(m.sets, & &1.score1)}
      end

    valid_score_pairs =
      Enum.zip(my_scores, opp_scores)
      |> Enum.filter(fn {a, b} -> not is_nil(a) and not is_nil(b) end)

    pw2 = Enum.sum(Enum.map(valid_score_pairs, fn {a, _} -> a end))
    pl2 = Enum.sum(Enum.map(valid_score_pairs, fn {_, b} -> b end))

    {sw + sw2, sl + sl2, pw + pw2, pl + pl2}
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.
  """
  def get_group!(id), do: Repo.get!(Group, id)

  @doc """
  Creates a group. Requires a superuser scope.
  """
  def create_group(%Scope{user: %{role: "superuser"}}, attrs) do
    stage_id = attrs["stage_id"] || attrs[:stage_id]

    with {:ok, _stage} <- fetch_stage_of_type(stage_id, "group") do
      %Group{}
      |> Group.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc """
  Updates a group. Requires a superuser scope.
  """
  def update_group(%Scope{user: %{role: "superuser"}}, %Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc """
  Deletes a group. Requires a superuser scope.
  """
  def delete_group(%Scope{user: %{role: "superuser"}}, %Group{} = group) do
    group
    |> Repo.delete()
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  """
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  # ---------------------------------------------------------------------------
  # Bracket slot assignment
  # ---------------------------------------------------------------------------

  @doc """
  Directly assigns a registration (or nil for bye/WO) to a slot on a bracket match.
  A team match with matches inside it keeps its teams (those matches' lineups
  belong to them): changing one returns `{:error, :has_inner_matches}`.
  Requires a superuser scope.
  """
  def assign_bracket_slot_direct(
        %Scope{user: %{role: "superuser"}},
        %Match{} = match,
        slot,
        registration_id
      )
      when slot in [1, 2] do
    field = if slot == 1, do: :registration1_id, else: :registration2_id

    if Map.fetch!(match, field) != registration_id and has_inner_matches?(match) do
      {:error, :has_inner_matches}
    else
      match
      |> Match.changeset(%{field => registration_id})
      |> Repo.update()
      |> broadcast_change()
    end
  end

  defp has_inner_matches?(%Match{id: id}),
    do: Repo.exists?(from(m in Match, where: m.team_match_id == ^id))

  # Generates 2^rounds - 1 placeholder matches for a bracket stage.
  defp generate_bracket_matches(%Stage{type: "bracket"} = stage) do
    rounds = stage.rounds
    now = DateTime.utc_now(:second)

    rows =
      for r <- 1..rounds,
          p <- 1..trunc(:math.pow(2, rounds - r)) do
        %{
          event_id: stage.event_id,
          stage_id: stage.id,
          round: r,
          position: p,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Match, rows)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fetch_stage_of_type(nil, _type), do: {:error, :stage_not_found}

  defp fetch_stage_of_type(stage_id, expected_type) do
    case Repo.get(Stage, stage_id) do
      nil -> {:error, :stage_not_found}
      %Stage{type: ^expected_type} = stage -> {:ok, stage}
      %Stage{} -> {:error, :stage_type_mismatch}
    end
  end

  # ---------------------------------------------------------------------------
  # Matches
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of matches for the given event.
  """
  def list_matches_for_event(event_id) do
    Match
    |> where([m], m.event_id == ^event_id)
    |> Repo.all()
    |> Repo.preload([
      :group,
      :stage,
      :sets,
      registration1: @registration_preload,
      registration2: @registration_preload,
      winner: @registration_preload
    ])
  end

  @doc """
  Gets a single match.

  Raises `Ecto.NoResultsError` if the Match does not exist.
  """
  def get_match!(id) do
    Repo.get!(Match, id)
    |> Repo.preload([
      :group,
      :stage,
      :sets,
      registration1: @registration_preload,
      registration2: @registration_preload,
      winner: @registration_preload
    ])
  end

  @doc """
  Creates a match. Requires a superuser scope.
  """
  def create_match(%Scope{user: %{role: "superuser"}}, attrs) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
    |> broadcast_change()
  end

  @doc """
  Updates a match. Requires a superuser scope.
  """
  def update_match(%Scope{user: %{role: "superuser"}}, %Match{} = match, attrs) do
    match |> Match.changeset(attrs) |> Repo.update() |> broadcast_change()
  end

  @doc """
  Deletes a match (and the matches inside it, for a team match) and
  recalculates the times of the tables they were on. Requires a superuser scope.
  """
  def delete_match(%Scope{user: %{role: "superuser"}}, %Match{} = match) do
    match_query = from(m in Match, where: m.id == ^match.id)

    with_tables_rescheduled(match.event_id, match_query, fn -> Repo.delete(match) end)
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match changes.
  """
  def change_match(%Match{} = match, attrs \\ %{}) do
    Match.changeset(match, attrs)
  end

  # ---------------------------------------------------------------------------
  # Team matches
  # ---------------------------------------------------------------------------

  @team_match_preloads [
    :sets,
    inner_matches:
      {from(im in Match, order_by: im.id),
       [
         :sets,
         :table,
         registration1: @registration_preload,
         registration2: @registration_preload,
         match_players: {from(mp in MatchPlayer, order_by: mp.id), :player}
       ]},
    group: [stage: :category],
    stage: :category,
    registration1: @registration_preload,
    registration2: @registration_preload
  ]

  @doc """
  Gets a team match of the event: a match in a group or bracket stage of a
  team category, with its teams (players and clubs), its group or stage and
  their category, and the matches inside it preloaded.

  Raises `Ecto.NoResultsError` if the match doesn't exist, belongs to another
  event or isn't a team match.
  """
  @spec get_team_match!(pos_integer(), pos_integer() | String.t()) :: Match.t()
  def get_team_match!(event_id, id) do
    event_id |> team_match_query(id) |> Repo.one!() |> Repo.preload(@team_match_preloads)
  end

  @doc """
  Like `get_team_match!/2`, but returns `nil` when the match doesn't exist,
  belongs to another event or isn't a team match.
  """
  @spec get_team_match(pos_integer(), pos_integer() | String.t()) :: Match.t() | nil
  def get_team_match(event_id, id) do
    case event_id |> team_match_query(id) |> Repo.one() do
      nil -> nil
      team_match -> Repo.preload(team_match, @team_match_preloads)
    end
  end

  defp team_match_query(event_id, id) do
    from(m in Match,
      left_join: g in assoc(m, :group),
      left_join: gs in assoc(g, :stage),
      left_join: s in assoc(m, :stage),
      join: c in Category,
      on: c.id == coalesce(gs.category_id, s.category_id),
      where: m.id == ^id and m.event_id == ^event_id and c.format == "team"
    )
  end

  @doc """
  The team match score: how many of the matches inside it each team won,
  as `{team1_wins, team2_wins}`.
  """
  @spec team_match_score(Match.t(), [Match.t()]) :: {non_neg_integer(), non_neg_integer()}
  def team_match_score(%Match{} = team_match, inner_matches) do
    {count_wins(inner_matches, team_match.registration1_id),
     count_wins(inner_matches, team_match.registration2_id)}
  end

  defp count_wins(_matches, nil), do: 0

  defp count_wins(matches, reg_id),
    do: Enum.count(matches, &(&1.winner_registration_id == reg_id))

  @doc """
  The team match status: `:finished` once it has a winner, `:ongoing` once any
  match inside it is ongoing or has a result, `:pending` otherwise.
  """
  @spec team_match_status(Match.t(), [Match.t()]) :: :finished | :ongoing | :pending
  def team_match_status(%Match{winner_registration_id: winner_id}, _inner)
      when not is_nil(winner_id),
      do: :finished

  def team_match_status(%Match{}, inner_matches) do
    if Enum.any?(inner_matches, &(&1.is_ongoing or not is_nil(&1.winner_registration_id))),
      do: :ongoing,
      else: :pending
  end

  @doc """
  Adds a match inside a team match (from `get_team_match!/2`): its kind,
  position labels, each side's players (`"player_ids1"`, `"player_ids2"`,
  picked from that side's team) and an optional `"table_id"`, which puts it at
  the end of that table's queue. Requires a superuser scope.
  """
  @spec create_inner_match(Scope.t(), Match.t(), map()) ::
          {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def create_inner_match(%Scope{user: %{role: "superuser"}}, %Match{} = team_match, attrs) do
    changeset = Match.inner_match_changeset(%Match{}, team_match, attrs)

    Repo.transaction(fn ->
      case changeset |> Ecto.Changeset.delete_change(:table_id) |> Repo.insert() do
        {:ok, match} -> move_to_table(match, Ecto.Changeset.get_field(changeset, :table_id))
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> broadcast_change()
  end

  @doc """
  Updates a match inside a team match: its lineup (see `create_inner_match/3`)
  and table. Moving it to another table puts it at the end of that queue;
  clearing the table unschedules it. Requires a superuser scope.
  """
  @spec update_inner_match(Scope.t(), Match.t(), Match.t(), map()) ::
          {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def update_inner_match(
        %Scope{user: %{role: "superuser"}},
        %Match{} = team_match,
        %Match{} = match,
        attrs
      ) do
    changeset =
      match |> Repo.preload(:match_players) |> Match.inner_match_changeset(team_match, attrs)

    Repo.transaction(fn ->
      case changeset |> Ecto.Changeset.delete_change(:table_id) |> Repo.update() do
        {:ok, updated} -> move_to_table(updated, Ecto.Changeset.get_field(changeset, :table_id))
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for the lineup form of a match inside a team match.
  """
  @spec change_inner_match(Match.t(), Match.t(), map()) :: Ecto.Changeset.t()
  def change_inner_match(%Match{} = team_match, %Match{} = match, attrs \\ %{}) do
    Match.inner_match_changeset(match, team_match, attrs)
  end

  # Same table: nothing to do. No table: leaves its queue (unscheduled). A new
  # table of the event: appended to its queue.
  defp move_to_table(%Match{table_id: table_id} = match, table_id), do: match

  defp move_to_table(%Match{table_id: old_table_id} = match, nil) do
    match =
      match
      |> Ecto.Changeset.change(
        table_id: nil,
        table_position: 0,
        scheduled_at: nil,
        is_ongoing: false
      )
      |> Repo.update!()

    reschedule_table(Repo.get!(Event, match.event_id), old_table_id)
    match
  end

  defp move_to_table(%Match{} = match, table_id) do
    event = Repo.get!(Event, match.event_id)

    case Repo.get_by(Table, id: table_id, event_id: event.id) do
      nil ->
        match

      %Table{} ->
        append_to_table(event, match, table_id)
        Repo.get!(Match, match.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Table schedule
  # ---------------------------------------------------------------------------

  @team_match_context_preloads [
    group: [stage: :category],
    stage: :category,
    registration1: @registration_preload,
    registration2: @registration_preload
  ]

  @schedule_preloads [
    group: [stage: :category],
    stage: :category,
    registration1: @registration_preload,
    registration2: @registration_preload,
    match_players: {from(mp in MatchPlayer, order_by: mp.id), :player},
    team_match: @team_match_context_preloads
  ]

  # Matches with their stage and category as named bindings (`:team_match`,
  # `:group`, `:stage`, `:category`), reached through the group, the bracket
  # stage or, for matches inside a team match, the team match's group or stage
  defp with_category(query) do
    query
    |> join(:left, [m], tm in Match, as: :team_match, on: tm.id == m.team_match_id)
    |> join(:left, [m, team_match: tm], g in Group,
      as: :group,
      on: g.id == coalesce(m.group_id, tm.group_id)
    )
    |> join(:inner, [m, team_match: tm, group: g], s in Stage,
      as: :stage,
      on: s.id == coalesce(coalesce(m.stage_id, tm.stage_id), g.stage_id)
    )
    |> join(:inner, [stage: s], c in Category, as: :category, on: c.id == s.category_id)
  end

  # Playable matches: team matches only wrap the matches inside them, they're
  # never played on a table. Needs `with_category/1`.
  defp playable(query) do
    where(query, [m, category: c], c.format != "team" or not is_nil(m.team_match_id))
  end

  defp playable_match_ids(event_id) do
    Match
    |> where([m], m.event_id == ^event_id)
    |> with_category()
    |> playable()
    |> select([m], m.id)
  end

  defp get_playable_match(event_id, match_id) do
    Match
    |> where([m], m.id == ^match_id and m.id in subquery(playable_match_ids(event_id)))
    |> Repo.one()
  end

  @doc """
  Gets a match inside a team match of the event, with the same preloads as
  `list_pending_inner_matches/1`, or `nil`.
  """
  @spec get_inner_match(pos_integer(), pos_integer()) :: Match.t() | nil
  def get_inner_match(event_id, id) do
    Match
    |> where([m], m.id == ^id and m.event_id == ^event_id and not is_nil(m.team_match_id))
    |> Repo.one()
    |> Repo.preload([:sets, :table | @schedule_preloads])
  end

  @doc """
  Returns the matches inside team matches of the event that have no winner
  yet, with their sets, table, players and team match (teams, group or stage
  and category) preloaded.
  """
  @spec list_pending_inner_matches(pos_integer()) :: [Match.t()]
  def list_pending_inner_matches(event_id) do
    Match
    |> where(
      [m],
      m.event_id == ^event_id and not is_nil(m.team_match_id) and
        is_nil(m.winner_registration_id) and not m.is_bye
    )
    |> order_by([m], m.id)
    |> Repo.all()
    |> Repo.preload([:sets, :table | @schedule_preloads])
  end

  @doc """
  Returns the match queue of every table in the event, as maps with `:table`,
  `:finished` and `:pending` keys. Finished matches (the ones with a winner)
  are frozen and ordered by time; pending matches follow the table queue order.
  Byes are not listed.
  """
  @spec list_table_schedules(pos_integer()) :: [
          %{table: Table.t(), finished: [Match.t()], pending: [Match.t()]}
        ]
  def list_table_schedules(event_id) do
    matches_by_table =
      Match
      |> where([m], m.event_id == ^event_id and not is_nil(m.table_id) and not m.is_bye)
      |> where([m], m.id in subquery(playable_match_ids(event_id)))
      |> order_by([m], [m.table_position, m.id])
      |> Repo.all()
      |> Repo.preload(@schedule_preloads)
      |> Enum.group_by(& &1.table_id)

    event_id
    |> Tables.list_tables_for_event()
    |> Enum.map(fn table ->
      {finished, pending} =
        matches_by_table
        |> Map.get(table.id, [])
        |> Enum.split_with(&finished?/1)

      # Stable sort: finished matches without time keep their queue order, at the end
      finished = Enum.sort_by(finished, &(&1.scheduled_at && DateTime.to_unix(&1.scheduled_at)))

      %{table: table, finished: finished, pending: pending}
    end)
  end

  @doc """
  Returns the pending matches of the event that are not assigned to any table
  yet, ordered by category, then stage/group/bracket order. Pass a
  `category_id` to list only that category's matches. Byes are not listed.
  """
  @spec list_unscheduled_matches(pos_integer(), pos_integer() | nil) :: [Match.t()]
  def list_unscheduled_matches(event_id, category_id \\ nil) do
    Match
    |> with_category()
    |> playable()
    |> where(
      [m],
      m.event_id == ^event_id and is_nil(m.table_id) and is_nil(m.winner_registration_id) and
        not m.is_bye
    )
    |> maybe_filter_category(category_id)
    # Matches inside a team match follow their team match's order, then their own
    |> order_by([m, team_match: tm, group: g, stage: s, category: c], [
      c.name,
      s.order,
      g.position,
      coalesce(tm.scheduled_position, m.scheduled_position),
      coalesce(tm.round, m.round),
      coalesce(tm.position, m.position),
      coalesce(tm.id, m.id),
      m.id
    ])
    |> Repo.all()
    |> Repo.preload(@schedule_preloads)
  end

  @doc """
  Rewrites match queues after a drag and drop and recalculates the times of the
  affected tables. Requires a superuser scope.

  `lists` holds the new state of each list touched by the move, as maps with
  `:table_id` (nil for the unscheduled pool) and `:match_ids` in queue order.
  Matches moved to the pool lose their table and time. Finished matches, byes,
  team matches, and matches or tables from other events are ignored.
  """
  @spec update_table_schedule(Scope.t(), Event.t(), [
          %{table_id: pos_integer() | nil, match_ids: [pos_integer()]}
        ]) :: :ok
  def update_table_schedule(%Scope{user: %{role: "superuser"}}, %Event{} = event, lists) do
    event_table_ids = MapSet.new(Tables.list_tables_for_event(event.id), & &1.id)

    lists =
      Enum.filter(lists, &(is_nil(&1.table_id) or MapSet.member?(event_table_ids, &1.table_id)))

    movable =
      from(m in Match,
        where:
          m.event_id == ^event.id and is_nil(m.winner_registration_id) and not m.is_bye and
            m.id in subquery(playable_match_ids(event.id))
      )

    moved_ids = Enum.flat_map(lists, & &1.match_ids)

    Repo.transaction(fn ->
      # Tables that lose a match need recalculation too
      previous_table_ids =
        movable
        |> where([m], m.id in ^moved_ids)
        |> where([m], not is_nil(m.table_id))
        |> select([m], m.table_id)
        |> Repo.all()

      Enum.each(lists, &write_schedule_list(movable, &1))

      (previous_table_ids ++ Enum.map(lists, & &1.table_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.each(&reschedule_table(event, &1))
    end)

    Events.broadcast_event_updated(event.id)
    :ok
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category_id),
    do: where(query, [stage: s], s.category_id == ^category_id)

  @doc """
  Adds a pending match to the end of a table queue and schedules it. Team
  matches can't be added. Requires a superuser scope.
  """
  @spec add_match_to_table(Scope.t(), Event.t(), pos_integer(), pos_integer()) ::
          :ok | {:error, :not_found}
  def add_match_to_table(%Scope{user: %{role: "superuser"}}, %Event{} = event, match_id, table_id) do
    with %Table{} <- Repo.get_by(Table, id: table_id, event_id: event.id),
         %Match{winner_registration_id: nil, is_bye: false} = match <-
           get_playable_match(event.id, match_id) do
      Repo.transaction(fn -> append_to_table(event, match, table_id) end)
      Events.broadcast_event_updated(event.id)
      :ok
    else
      _ -> {:error, :not_found}
    end
  end

  defp append_to_table(event, match, table_id) do
    last_position =
      from(m in Match, where: m.table_id == ^table_id, select: max(m.table_position))
      |> Repo.one()

    match
    |> Ecto.Changeset.change(table_id: table_id, table_position: (last_position || -1) + 1)
    |> Repo.update!()

    # The table the match came from (if any) loses it
    if match.table_id, do: reschedule_table(event, match.table_id)
    reschedule_table(event, table_id)
  end

  # Matches moved to the pool lose their table and time, and can't be ongoing
  defp write_schedule_list(movable, %{table_id: nil, match_ids: ids}) do
    movable
    |> where([m], m.id in ^ids)
    |> Repo.update_all(
      set: [table_id: nil, table_position: 0, scheduled_at: nil, is_ongoing: false]
    )
  end

  defp write_schedule_list(movable, %{table_id: table_id, match_ids: ids}) do
    # A match moved in from another table is not being played there
    movable
    |> where([m], m.id in ^ids and m.table_id != ^table_id)
    |> Repo.update_all(set: [is_ongoing: false])

    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, index} ->
      movable
      |> where([m], m.id == ^id)
      |> Repo.update_all(set: [table_id: table_id, table_position: index])
    end)
  end

  @doc """
  Marks a match as being played (or not). Only the first pending match of a
  table queue can be ongoing. The table times are recalculated, as an ongoing
  match anchors the ones that follow it. Requires a superuser scope.
  """
  @spec set_match_ongoing(Scope.t(), Event.t(), pos_integer(), boolean()) ::
          :ok | {:error, :not_found}
  def set_match_ongoing(%Scope{user: %{role: "superuser"}}, %Event{} = event, match_id, ongoing?) do
    with %Match{winner_registration_id: nil, is_bye: false, table_id: table_id} = match
         when not is_nil(table_id) <- get_playable_match(event.id, match_id),
         ^match_id <- first_pending_match_id(table_id) do
      Repo.transaction(fn ->
        match |> Ecto.Changeset.change(is_ongoing: ongoing?) |> Repo.update!()
        reschedule_table(event, table_id)
      end)

      Events.broadcast_event_updated(event.id)
      :ok
    else
      _ -> {:error, :not_found}
    end
  end

  defp first_pending_match_id(table_id) do
    from(m in Match,
      where: m.table_id == ^table_id and is_nil(m.winner_registration_id) and not m.is_bye,
      order_by: [m.table_position, m.id],
      limit: 1,
      select: m.id
    )
    |> Repo.one()
  end

  @doc """
  Recalculates the times of the pending matches of a table. Requires a superuser scope.
  """
  @spec recalculate_table_schedule(Scope.t(), Event.t(), pos_integer()) :: :ok
  def recalculate_table_schedule(%Scope{user: %{role: "superuser"}}, %Event{} = event, table_id) do
    reschedule_table(event, table_id)
    Events.broadcast_event_updated(event.id)
    :ok
  end

  @doc """
  Updates the event's current match duration and recalculates the times of the
  pending matches of every table. Requires a superuser scope.
  """
  @spec update_match_duration(Scope.t(), Event.t(), map()) ::
          {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def update_match_duration(%Scope{user: %{role: "superuser"}}, %Event{} = event, attrs) do
    Repo.transaction(fn ->
      case event |> Event.match_duration_changeset(attrs) |> Repo.update() do
        {:ok, event} ->
          event.id
          |> Tables.list_tables_for_event()
          |> Enum.each(&reschedule_table(event, &1.id))

          event

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking the event's match duration.
  """
  def change_match_duration(%Event{} = event, attrs \\ %{}) do
    Event.match_duration_changeset(event, attrs)
  end

  # An ongoing first pending match keeps its time (it already started, and its
  # time can be edited), anchoring the ones that follow. Otherwise the first
  # pending match starts right after the latest finished match (whose time is
  # frozen), or at the event start when nothing was played yet. Each following
  # match starts one match duration later. Only the first pending match can be
  # ongoing, so the ones pushed down the queue stop being ongoing.
  defp reschedule_table(%Event{} = event, table_id) do
    {finished, pending} =
      Match
      |> where([m], m.event_id == ^event.id and m.table_id == ^table_id and not m.is_bye)
      |> order_by([m], [m.table_position, m.id])
      |> Repo.all()
      |> Enum.split_with(&finished?/1)

    start_at =
      case {pending, finished |> Enum.map(& &1.scheduled_at) |> Enum.reject(&is_nil/1)} do
        {[%Match{is_ongoing: true, scheduled_at: %DateTime{} = current_at} | _], _} ->
          current_at

        {_, []} ->
          event.datetime

        {_, times} ->
          times |> Enum.max(DateTime) |> DateTime.add(event.match_duration_minutes, :minute)
      end

    pending
    |> Enum.with_index()
    |> Enum.each(fn {match, index} ->
      scheduled_at = DateTime.add(start_at, index * event.match_duration_minutes, :minute)
      is_ongoing = index == 0 and match.is_ongoing

      from(m in Match, where: m.id == ^match.id)
      |> Repo.update_all(
        set: [table_position: index, scheduled_at: scheduled_at, is_ongoing: is_ongoing]
      )
    end)
  end

  defp finished?(%Match{winner_registration_id: winner_id}), do: not is_nil(winner_id)

  # Runs `delete_fun`, which deletes the matches of `matches_query` (and, by
  # cascade, the matches inside them), then recalculates the times of the
  # tables those matches were on
  defp with_tables_rescheduled(event_id, matches_query, delete_fun) do
    match_ids = select(matches_query, [m], m.id)

    table_ids =
      from(m in Match,
        where: m.id in subquery(match_ids) or m.team_match_id in subquery(match_ids),
        where: not is_nil(m.table_id),
        distinct: true,
        select: m.table_id
      )
      |> Repo.all()

    result = delete_fun.()

    if table_ids != [] do
      event = Repo.get!(Event, event_id)
      Enum.each(table_ids, &reschedule_table(event, &1))
    end

    result
  end

  # ---------------------------------------------------------------------------
  # Match Sets
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of sets for the given match.
  """
  def list_sets_for_match(match_id) do
    MatchSet
    |> where([s], s.match_id == ^match_id)
    |> order_by([s], s.set_number)
    |> Repo.all()
  end

  @doc """
  Gets a single match set.

  Raises `Ecto.NoResultsError` if the MatchSet does not exist.
  """
  def get_match_set!(id), do: Repo.get!(MatchSet, id)

  @doc """
  Creates a match set. Requires a superuser scope.
  """
  def create_match_set(%Scope{user: %{role: "superuser"}}, attrs) do
    %MatchSet{}
    |> MatchSet.changeset(attrs)
    |> Repo.insert()
    |> broadcast_change()
  end

  @doc """
  Updates a match set. Requires a superuser scope.
  """
  def update_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set, attrs) do
    match_set
    |> MatchSet.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc """
  Deletes a match set. Requires a superuser scope.
  """
  def delete_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set) do
    match_set
    |> Repo.delete()
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match set changes.
  """
  def change_match_set(%MatchSet{} = match_set, attrs \\ %{}) do
    MatchSet.changeset(match_set, attrs)
  end

  # ---------------------------------------------------------------------------
  # Dashboard metrics
  # ---------------------------------------------------------------------------

  @doc """
  Returns match counts per category for a given event. Byes and team matches
  are not counted (the matches inside team matches are).
  """
  @spec count_matches_per_category(pos_integer()) :: [
          %{category_name: String.t(), count: integer()}
        ]
  def count_matches_per_category(event_id) do
    Match
    |> where([m], m.event_id == ^event_id and not m.is_bye)
    |> with_category()
    |> playable()
    |> group_by([category: c], c.name)
    |> select([m, category: c], %{category_name: c.name, count: count(m.id)})
    |> order_by([category: c], c.name)
    |> Repo.all()
  end

  @doc """
  Returns finished vs unfinished match counts for a given event. Byes and team
  matches are not counted.
  """
  @spec count_matches_by_status(pos_integer()) :: %{
          finished: integer(),
          unfinished: integer()
        }
  def count_matches_by_status(event_id) do
    result =
      Match
      |> where([m], m.event_id == ^event_id and not m.is_bye)
      |> where([m], m.id in subquery(playable_match_ids(event_id)))
      |> select([m], %{
        finished: count() |> filter(not is_nil(m.winner_registration_id)),
        unfinished: count() |> filter(is_nil(m.winner_registration_id))
      })
      |> Repo.one()

    result || %{finished: 0, unfinished: 0}
  end

  @doc """
  Returns match counts per table and unassigned unfinished count for a given event.
  Byes and team matches are not counted.
  """
  @spec count_matches_per_table(pos_integer()) ::
          {%{pos_integer() => %{finished: integer(), unfinished: integer()}}, integer()}
  def count_matches_per_table(event_id) do
    rows =
      Match
      |> where([m], m.event_id == ^event_id and not m.is_bye)
      |> where([m], m.id in subquery(playable_match_ids(event_id)))
      |> group_by([m], m.table_id)
      |> select([m], %{
        table_id: m.table_id,
        finished: count() |> filter(not is_nil(m.winner_registration_id)),
        unfinished: count() |> filter(is_nil(m.winner_registration_id))
      })
      |> Repo.all()

    {unassigned_rows, table_rows} = Enum.split_with(rows, &is_nil(&1.table_id))

    table_counts =
      Map.new(table_rows, fn row ->
        {row.table_id, %{finished: row.finished, unfinished: row.unfinished}}
      end)

    unassigned =
      case unassigned_rows do
        [row] -> row.unfinished
        [] -> 0
      end

    {table_counts, unassigned}
  end

  # ---------------------------------------------------------------------------
  # Broadcasts
  # ---------------------------------------------------------------------------

  # Notifies the subscribers of the event a changed record belongs to
  defp broadcast_change({:ok, %Event{id: event_id}} = result) do
    Events.broadcast_event_updated(event_id)
    result
  end

  defp broadcast_change({:ok, %Group{stage_id: stage_id}} = result) do
    from(s in Stage, where: s.id == ^stage_id, select: s.event_id)
    |> Repo.one()
    |> maybe_broadcast_event_updated()

    result
  end

  defp broadcast_change({:ok, %MatchSet{match_id: match_id}} = result) do
    from(m in Match, where: m.id == ^match_id, select: m.event_id)
    |> Repo.one()
    |> maybe_broadcast_event_updated()

    result
  end

  defp broadcast_change({:ok, %{event_id: event_id}} = result) do
    Events.broadcast_event_updated(event_id)
    result
  end

  defp broadcast_change(result), do: result

  defp broadcast_group_change(group_id) do
    from(g in Group, join: s in assoc(g, :stage), where: g.id == ^group_id, select: s.event_id)
    |> Repo.one()
    |> maybe_broadcast_event_updated()
  end

  defp maybe_broadcast_event_updated(nil), do: :ok
  defp maybe_broadcast_event_updated(event_id), do: Events.broadcast_event_updated(event_id)
end
