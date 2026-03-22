defmodule T3System.Matches do
  @moduledoc """
  The Matches context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration

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
  def list_stages_for_event_and_category(event_id, category_id) do
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
             registration1: [:player, :club],
             registration2: [:player, :club],
             winner: [:player]
           ]
         ]},
      matches: [
        :sets,
        registration1: [:player, :club],
        registration2: [:player, :club],
        winner: [:player]
      ]
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
    Repo.get!(Group, id) |> Repo.preload(registrations: [:player, :club])
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
end
