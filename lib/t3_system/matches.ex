defmodule T3System.Matches do
  @moduledoc """
  The Matches context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration
  alias T3System.Tables
  alias T3System.Tables.Table

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

    bracket_matches_query =
      if exclude_byes,
        do: from(m in Match, where: not m.is_bye),
        else: from(m in Match)

    Stage
    |> where([s], s.event_id == ^event_id and s.category_id == ^category_id)
    |> order_by([s], s.order)
    |> Repo.all()
    |> Repo.preload(
      groups:
        {from(g in Group, order_by: g.position),
         [
           registrations: [:player, :club],
           matches: [
             :sets,
             :table,
             registration1: [:player, :club],
             registration2: [:player, :club],
             winner: [:player]
           ]
         ]},
      matches:
        {bracket_matches_query,
         [
           :sets,
           :table,
           registration1: [:player, :club],
           registration2: [:player, :club],
           winner: [:player]
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

    if type == "bracket" and rounds do
      create_bracket_stage(attrs)
    else
      %Stage{}
      |> Stage.changeset(attrs)
      |> Repo.insert()
    end
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
  end

  @doc """
  Deletes a stage. Requires a superuser scope.
  """
  def delete_stage(%Scope{user: %{role: "superuser"}}, %Stage{} = stage) do
    Repo.delete(stage)
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
    Repo.transaction(fn ->
      from(m in Match, where: m.stage_id == ^stage.id) |> Repo.delete_all()

      case stage |> Stage.changeset(%{rounds: rounds}) |> Repo.update() do
        {:ok, stage} ->
          generate_bracket_matches(stage)
          stage

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
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
      registrations: [:player, :club],
      matches: [
        :sets,
        registration1: [:player, :club],
        registration2: [:player, :club],
        winner: [:player]
      ]
    )
  end

  @doc """
  Returns a group with its registrations (including player and club) preloaded.
  """
  def get_group_with_registrations!(id) do
    Repo.get!(Group, id) |> Repo.preload([:matches, registrations: [:player, :club]])
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

    Repo.transaction(fn ->
      from(m in Match, where: m.group_id == ^group.id) |> Repo.delete_all()
      {count, _} = Repo.insert_all(Match, build_match_rows(pairs, group))
      count
    end)
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
  set_diff, point_diff, rank, qualified.
  """
  def compute_group_standings(%Group{matches: matches} = group) do
    qualifies_count = group.qualifies_count

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

        {sets_won, sets_lost, pts_won, pts_lost} =
          Enum.reduce(my_matches, {0, 0, 0, 0}, &accumulate_set_stats(&1, reg.id, &2))

        %{
          registration: reg,
          played: played,
          won: won,
          lost: lost,
          set_diff: sets_won - sets_lost,
          point_diff: pts_won - pts_lost
        }
      end)

    stats
    |> Enum.sort_by(fn s -> {-s.won, -s.set_diff, -s.point_diff} end)
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
    end
  end

  @doc """
  Updates a group. Requires a superuser scope.
  """
  def update_group(%Scope{user: %{role: "superuser"}}, %Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group. Requires a superuser scope.
  """
  def delete_group(%Scope{user: %{role: "superuser"}}, %Group{} = group) do
    Repo.delete(group)
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
  Requires a superuser scope.
  """
  def assign_bracket_slot_direct(
        %Scope{user: %{role: "superuser"}},
        %Match{} = match,
        slot,
        registration_id
      )
      when slot in [1, 2] do
    slot_attrs =
      case slot do
        1 -> %{registration1_id: registration_id}
        2 -> %{registration2_id: registration_id}
      end

    match
    |> Match.changeset(slot_attrs)
    |> Repo.update()
  end

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
      registration1: [:player],
      registration2: [:player],
      winner: [:player]
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
      registration1: [:player],
      registration2: [:player],
      winner: [:player]
    ])
  end

  @doc """
  Creates a match. Requires a superuser scope.
  """
  def create_match(%Scope{user: %{role: "superuser"}}, attrs) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match. Requires a superuser scope.
  """
  def update_match(%Scope{user: %{role: "superuser"}}, %Match{} = match, attrs) do
    match |> Match.changeset(attrs) |> Repo.update()
  end

  @doc """
  Deletes a match. Requires a superuser scope.
  """
  def delete_match(%Scope{user: %{role: "superuser"}}, %Match{} = match) do
    Repo.delete(match)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match changes.
  """
  def change_match(%Match{} = match, attrs \\ %{}) do
    Match.changeset(match, attrs)
  end

  # ---------------------------------------------------------------------------
  # Table schedule
  # ---------------------------------------------------------------------------

  @schedule_preloads [
    group: [stage: :category],
    stage: :category,
    registration1: :player,
    registration2: :player
  ]

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
    |> join(:left, [m], g in Group, on: m.group_id == g.id)
    |> join(:inner, [m, g], s in Stage, on: s.id == coalesce(m.stage_id, g.stage_id))
    |> join(:inner, [m, g, s], c in Category, on: c.id == s.category_id)
    |> where(
      [m],
      m.event_id == ^event_id and is_nil(m.table_id) and is_nil(m.winner_registration_id) and
        not m.is_bye
    )
    |> maybe_filter_category(category_id)
    |> order_by([m, g, s, c], [
      c.name,
      s.order,
      g.position,
      m.scheduled_position,
      m.round,
      m.position,
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
  and matches or tables from other events are ignored.
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
        where: m.event_id == ^event.id and is_nil(m.winner_registration_id) and not m.is_bye
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

    :ok
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category_id),
    do: where(query, [m, g, s], s.category_id == ^category_id)

  @doc """
  Adds a pending match to the end of a table queue and schedules it.
  Requires a superuser scope.
  """
  @spec add_match_to_table(Scope.t(), Event.t(), pos_integer(), pos_integer()) ::
          :ok | {:error, :not_found}
  def add_match_to_table(%Scope{user: %{role: "superuser"}}, %Event{} = event, match_id, table_id) do
    with %Table{} <- Repo.get_by(Table, id: table_id, event_id: event.id),
         %Match{winner_registration_id: nil, is_bye: false} = match <-
           Repo.get_by(Match, id: match_id, event_id: event.id) do
      Repo.transaction(fn -> append_to_table(event, match, table_id) end)
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

  # Matches moved to the pool lose their table and time
  defp write_schedule_list(movable, %{table_id: nil, match_ids: ids}) do
    movable
    |> where([m], m.id in ^ids)
    |> Repo.update_all(set: [table_id: nil, table_position: 0, scheduled_at: nil])
  end

  defp write_schedule_list(movable, %{table_id: table_id, match_ids: ids}) do
    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, index} ->
      movable
      |> where([m], m.id == ^id)
      |> Repo.update_all(set: [table_id: table_id, table_position: index])
    end)
  end

  @doc """
  Recalculates the times of the pending matches of a table. Requires a superuser scope.
  """
  @spec recalculate_table_schedule(Scope.t(), Event.t(), pos_integer()) :: :ok
  def recalculate_table_schedule(%Scope{user: %{role: "superuser"}}, %Event{} = event, table_id) do
    reschedule_table(event, table_id)
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
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking the event's match duration.
  """
  def change_match_duration(%Event{} = event, attrs \\ %{}) do
    Event.match_duration_changeset(event, attrs)
  end

  # The first pending match starts right after the latest finished match (whose
  # time is frozen), or at the event start when nothing was played yet. Each
  # following match starts one match duration later.
  defp reschedule_table(%Event{} = event, table_id) do
    {finished, pending} =
      Match
      |> where([m], m.event_id == ^event.id and m.table_id == ^table_id and not m.is_bye)
      |> order_by([m], [m.table_position, m.id])
      |> Repo.all()
      |> Enum.split_with(&finished?/1)

    start_at =
      case finished |> Enum.map(& &1.scheduled_at) |> Enum.reject(&is_nil/1) do
        [] ->
          event.datetime

        times ->
          times |> Enum.max(DateTime) |> DateTime.add(event.match_duration_minutes, :minute)
      end

    pending
    |> Enum.with_index()
    |> Enum.each(fn {match, index} ->
      scheduled_at = DateTime.add(start_at, index * event.match_duration_minutes, :minute)

      from(m in Match, where: m.id == ^match.id)
      |> Repo.update_all(set: [table_position: index, scheduled_at: scheduled_at])
    end)
  end

  defp finished?(%Match{winner_registration_id: winner_id}), do: not is_nil(winner_id)

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
  end

  @doc """
  Updates a match set. Requires a superuser scope.
  """
  def update_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set, attrs) do
    match_set
    |> MatchSet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a match set. Requires a superuser scope.
  """
  def delete_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set) do
    Repo.delete(match_set)
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
  Returns match counts per category for a given event. Byes are not counted.
  """
  @spec count_matches_per_category(pos_integer()) :: [
          %{category_name: String.t(), count: integer()}
        ]
  def count_matches_per_category(event_id) do
    Match
    |> where([m], m.event_id == ^event_id and not m.is_bye)
    |> join(:left, [m], g in Group, on: m.group_id == g.id)
    |> join(:inner, [m, g], s in Stage, on: s.id == coalesce(m.stage_id, g.stage_id))
    |> join(:inner, [m, g, s], c in Category, on: c.id == s.category_id)
    |> group_by([m, g, s, c], c.name)
    |> select([m, g, s, c], %{category_name: c.name, count: count(m.id)})
    |> order_by([m, g, s, c], c.name)
    |> Repo.all()
  end

  @doc """
  Returns finished vs unfinished match counts for a given event. Byes are not counted.
  """
  @spec count_matches_by_status(pos_integer()) :: %{
          finished: integer(),
          unfinished: integer()
        }
  def count_matches_by_status(event_id) do
    result =
      Match
      |> where([m], m.event_id == ^event_id and not m.is_bye)
      |> select([m], %{
        finished: count() |> filter(not is_nil(m.winner_registration_id)),
        unfinished: count() |> filter(is_nil(m.winner_registration_id))
      })
      |> Repo.one()

    result || %{finished: 0, unfinished: 0}
  end

  @doc """
  Returns match counts per table and unassigned unfinished count for a given event.
  Byes are not counted.
  """
  @spec count_matches_per_table(pos_integer()) ::
          {%{pos_integer() => %{finished: integer(), unfinished: integer()}}, integer()}
  def count_matches_per_table(event_id) do
    rows =
      Match
      |> where([m], m.event_id == ^event_id and not m.is_bye)
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
end
