defmodule T3System.Matches do
  @moduledoc """
  The Matches context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Matches.Bracket
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet
  alias T3System.Registrations.Registration

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of groups for the given event.

  ## Examples

      iex> list_groups_for_event(event_id)
      [%Group{}, ...]

  """
  def list_groups_for_event(event_id) do
    Group
    |> where([g], g.event_id == ^event_id)
    |> Repo.all()
  end

  @doc """
  Returns groups for the given event and category, with members and matches
  preloaded for standings computation.
  """
  def list_groups_for_event_and_category(event_id, category_id) do
    Group
    |> where([g], g.event_id == ^event_id and g.category_id == ^category_id)
    |> order_by([g], g.name)
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
    group = Repo.preload(group, :registrations)
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

    Enum.map(pairs, fn {r1, r2} ->
      %{
        event_id: group.event_id,
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
      Map.merge(s, %{rank: rank, qualified: rank <= qualifies_count})
    end)
  end

  defp accumulate_set_stats(m, reg_id, {sw, sl, pw, pl}) do
    {my_scores, opp_scores} =
      if m.registration1_id == reg_id do
        {Enum.map(m.sets, & &1.score1), Enum.map(m.sets, & &1.score2)}
      else
        {Enum.map(m.sets, & &1.score2), Enum.map(m.sets, & &1.score1)}
      end

    valid_sets =
      Enum.zip(my_scores, opp_scores)
      |> Enum.filter(fn {a, b} -> not is_nil(a) and not is_nil(b) end)

    sw2 = Enum.count(valid_sets, fn {a, b} -> a > b end)
    sl2 = Enum.count(valid_sets, fn {a, b} -> b > a end)
    pw2 = Enum.sum(Enum.map(valid_sets, fn {a, _} -> a end))
    pl2 = Enum.sum(Enum.map(valid_sets, fn {_, b} -> b end))

    {sw + sw2, sl + sl2, pw + pw2, pl + pl2}
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id), do: Repo.get!(Group, id)

  @doc """
  Creates a group. Requires a superuser scope.

  ## Examples

      iex> create_group(superuser_scope, %{field: value})
      {:ok, %Group{}}

      iex> create_group(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_group(%Scope{user: %{role: "superuser"}}, attrs) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group. Requires a superuser scope.

  ## Examples

      iex> update_group(superuser_scope, group, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group(non_superuser_scope, group, %{field: value})
      ** (FunctionClauseError)

  """
  def update_group(%Scope{user: %{role: "superuser"}}, %Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group. Requires a superuser scope.

  ## Examples

      iex> delete_group(superuser_scope, group)
      {:ok, %Group{}}

      iex> delete_group(non_superuser_scope, group)
      ** (FunctionClauseError)

  """
  def delete_group(%Scope{user: %{role: "superuser"}}, %Group{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group(group)
      %Ecto.Changeset{data: %Group{}}

  """
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  # ---------------------------------------------------------------------------
  # Brackets
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of brackets for the given event.

  ## Examples

      iex> list_brackets_for_event(event_id)
      [%Bracket{}, ...]

  """
  def list_brackets_for_event(event_id) do
    Bracket
    |> where([b], b.event_id == ^event_id)
    |> Repo.all()
  end

  @doc """
  Returns the bracket for the given event and category with matches fully preloaded,
  or nil if none exists.
  """
  def get_bracket_for_event_and_category(event_id, category_id) do
    Bracket
    |> where([b], b.event_id == ^event_id and b.category_id == ^category_id)
    |> Repo.one()
    |> case do
      nil ->
        nil

      bracket ->
        Repo.preload(bracket,
          matches: [
            :sets,
            :source1_group,
            :source2_group,
            registration1: [:player, :club],
            registration2: [:player, :club],
            winner: [:player]
          ]
        )
    end
  end

  @doc """
  Gets a single bracket.

  Raises `Ecto.NoResultsError` if the Bracket does not exist.

  ## Examples

      iex> get_bracket!(123)
      %Bracket{}

      iex> get_bracket!(456)
      ** (Ecto.NoResultsError)

  """
  def get_bracket!(id), do: Repo.get!(Bracket, id)

  @doc """
  Creates a bracket and generates placeholder matches for all rounds.
  Deletes any existing bracket for the same event+category first.
  Requires a superuser scope.

  ## Examples

      iex> create_bracket(superuser_scope, %{field: value})
      {:ok, %Bracket{}}

      iex> create_bracket(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_bracket(%Scope{user: %{role: "superuser"}}, attrs) do
    event_id = attrs["event_id"] || attrs[:event_id]
    category_id = attrs["category_id"] || attrs[:category_id]

    Repo.transaction(fn ->
      # Delete any existing bracket for this event+category
      if event_id && category_id do
        from(b in Bracket,
          where: b.event_id == ^event_id and b.category_id == ^category_id
        )
        |> Repo.delete_all()
      end

      case %Bracket{} |> Bracket.changeset(attrs) |> Repo.insert() do
        {:ok, bracket} ->
          generate_bracket_matches(bracket)
          bracket

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a bracket. Requires a superuser scope.

  ## Examples

      iex> update_bracket(superuser_scope, bracket, %{field: new_value})
      {:ok, %Bracket{}}

      iex> update_bracket(non_superuser_scope, bracket, %{field: value})
      ** (FunctionClauseError)

  """
  def update_bracket(%Scope{user: %{role: "superuser"}}, %Bracket{} = bracket, attrs) do
    bracket
    |> Bracket.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bracket. Requires a superuser scope.

  ## Examples

      iex> delete_bracket(superuser_scope, bracket)
      {:ok, %Bracket{}}

      iex> delete_bracket(non_superuser_scope, bracket)
      ** (FunctionClauseError)

  """
  def delete_bracket(%Scope{user: %{role: "superuser"}}, %Bracket{} = bracket) do
    Repo.delete(bracket)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bracket changes.

  ## Examples

      iex> change_bracket(bracket)
      %Ecto.Changeset{data: %Bracket{}}

  """
  def change_bracket(%Bracket{} = bracket, attrs \\ %{}) do
    Bracket.changeset(bracket, attrs)
  end

  @doc """
  Assigns a source group and rank to a slot on a first-round bracket match.
  Also updates the registration slot if standings can be resolved.
  Requires a superuser scope.
  """
  def assign_bracket_slot(%Scope{user: %{role: "superuser"}}, %Match{} = match, slot, group_id, rank)
      when slot in [1, 2] do
    group =
      Repo.get!(Group, group_id)
      |> Repo.preload(
        registrations: [:player, :club],
        matches: [
          :sets,
          registration1: [:player, :club],
          registration2: [:player, :club],
          winner: [:player]
        ]
      )

    standings = compute_group_standings(group)
    row = Enum.find(standings, &(&1.rank == rank))
    registration_id = row && row.registration.id

    slot_attrs =
      case slot do
        1 ->
          %{
            source1_group_id: group_id,
            source1_rank: rank,
            registration1_id: registration_id
          }

        2 ->
          %{
            source2_group_id: group_id,
            source2_rank: rank,
            registration2_id: registration_id
          }
      end

    match
    |> Match.changeset(slot_attrs)
    |> Repo.update()
  end

  @doc """
  Directly assigns a registration (or nil for bye/WO) to a slot on a bracket match.
  Clears any source group/rank for that slot. Requires a superuser scope.
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
        1 ->
          %{
            source1_group_id: nil,
            source1_rank: nil,
            registration1_id: registration_id
          }

        2 ->
          %{
            source2_group_id: nil,
            source2_rank: nil,
            registration2_id: registration_id
          }
      end

    match
    |> Match.changeset(slot_attrs)
    |> Repo.update()
  end

  # Generates 2^rounds - 1 placeholder matches for a bracket.
  # Matches are linked by next_match_id forming a single-elimination tree.
  defp generate_bracket_matches(%Bracket{} = bracket) do
    rounds = bracket.rounds
    now = DateTime.utc_now(:second)

    rows =
      for r <- 1..rounds,
          p <- 1..trunc(:math.pow(2, rounds - r)) do
        %{
          event_id: bracket.event_id,
          bracket_id: bracket.id,
          round: r,
          position: p,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Match, rows)

    # Fetch back with IDs to wire up next_match_id
    matches =
      Match
      |> where([m], m.bracket_id == ^bracket.id)
      |> order_by([m], [m.round, m.position])
      |> Repo.all()

    match_map = Map.new(matches, fn m -> {{m.round, m.position}, m.id} end)

    # Update next_match_id for all non-final matches
    for m <- matches, m.round < rounds do
      next_pos = ceil(m.position / 2)
      next_id = Map.get(match_map, {m.round + 1, next_pos})

      from(match in Match, where: match.id == ^m.id)
      |> Repo.update_all(set: [next_match_id: next_id])
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Matches
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of matches for the given event.

  ## Examples

      iex> list_matches_for_event(event_id)
      [%Match{}, ...]

  """
  def list_matches_for_event(event_id) do
    Match
    |> where([m], m.event_id == ^event_id)
    |> Repo.all()
    |> Repo.preload([
      :group,
      :bracket,
      :sets,
      registration1: [:player],
      registration2: [:player],
      winner: [:player]
    ])
  end

  @doc """
  Gets a single match.

  Raises `Ecto.NoResultsError` if the Match does not exist.

  ## Examples

      iex> get_match!(123)
      %Match{}

      iex> get_match!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match!(id) do
    Repo.get!(Match, id)
    |> Repo.preload([
      :group,
      :bracket,
      :sets,
      registration1: [:player],
      registration2: [:player],
      winner: [:player]
    ])
  end

  @doc """
  Creates a match. Requires a superuser scope.

  ## Examples

      iex> create_match(superuser_scope, %{field: value})
      {:ok, %Match{}}

      iex> create_match(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_match(%Scope{user: %{role: "superuser"}}, attrs) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match. Requires a superuser scope.
  After a successful update, if this is a bracket match and a winner was just set,
  advances the winner to the appropriate slot in the next match.

  ## Examples

      iex> update_match(superuser_scope, match, %{field: new_value})
      {:ok, %Match{}}

      iex> update_match(non_superuser_scope, match, %{field: value})
      ** (FunctionClauseError)

  """
  def update_match(%Scope{user: %{role: "superuser"}}, %Match{} = match, attrs) do
    case match |> Match.changeset(attrs) |> Repo.update() do
      {:ok, updated_match} ->
        maybe_advance_bracket_winner(updated_match)
        {:ok, updated_match}

      error ->
        error
    end
  end

  @doc """
  Deletes a match. Requires a superuser scope.

  ## Examples

      iex> delete_match(superuser_scope, match)
      {:ok, %Match{}}

      iex> delete_match(non_superuser_scope, match)
      ** (FunctionClauseError)

  """
  def delete_match(%Scope{user: %{role: "superuser"}}, %Match{} = match) do
    Repo.delete(match)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match changes.

  ## Examples

      iex> change_match(match)
      %Ecto.Changeset{data: %Match{}}

  """
  def change_match(%Match{} = match, attrs \\ %{}) do
    Match.changeset(match, attrs)
  end

  # After a bracket match gets a winner, propagate to next match's appropriate slot.
  defp maybe_advance_bracket_winner(%Match{next_match_id: nil}), do: :ok
  defp maybe_advance_bracket_winner(%Match{winner_registration_id: nil}), do: :ok

  defp maybe_advance_bracket_winner(%Match{} = match) do
    next_match = Repo.get!(Match, match.next_match_id)

    slot_attrs =
      if rem(match.position, 2) == 1 do
        %{registration1_id: match.winner_registration_id}
      else
        %{registration2_id: match.winner_registration_id}
      end

    next_match
    |> Match.changeset(slot_attrs)
    |> Repo.update()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Match Sets
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of sets for the given match.

  ## Examples

      iex> list_sets_for_match(match_id)
      [%MatchSet{}, ...]

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

  ## Examples

      iex> get_match_set!(123)
      %MatchSet{}

      iex> get_match_set!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match_set!(id), do: Repo.get!(MatchSet, id)

  @doc """
  Creates a match set. Requires a superuser scope.

  Resolves `points_per_set` from the match's group (for group matches) or
  from the match itself (for bracket matches) to apply deuce validation.

  ## Examples

      iex> create_match_set(superuser_scope, %{field: value})
      {:ok, %MatchSet{}}

      iex> create_match_set(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_match_set(%Scope{user: %{role: "superuser"}}, attrs) do
    points_per_set = resolve_points_per_set(attrs)

    %MatchSet{}
    |> MatchSet.changeset(attrs, points_per_set: points_per_set)
    |> Repo.insert()
  end

  @doc """
  Updates a match set. Requires a superuser scope.

  ## Examples

      iex> update_match_set(superuser_scope, match_set, %{field: new_value})
      {:ok, %MatchSet{}}

      iex> update_match_set(non_superuser_scope, match_set, %{field: value})
      ** (FunctionClauseError)

  """
  def update_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set, attrs) do
    points_per_set = resolve_points_per_set_for_set(match_set, attrs)

    match_set
    |> MatchSet.changeset(attrs, points_per_set: points_per_set)
    |> Repo.update()
  end

  @doc """
  Deletes a match set. Requires a superuser scope.

  ## Examples

      iex> delete_match_set(superuser_scope, match_set)
      {:ok, %MatchSet{}}

      iex> delete_match_set(non_superuser_scope, match_set)
      ** (FunctionClauseError)

  """
  def delete_match_set(%Scope{user: %{role: "superuser"}}, %MatchSet{} = match_set) do
    Repo.delete(match_set)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match set changes.

  ## Examples

      iex> change_match_set(match_set)
      %Ecto.Changeset{data: %MatchSet{}}

  """
  def change_match_set(%MatchSet{} = match_set, attrs \\ %{}, opts \\ []) do
    MatchSet.changeset(match_set, attrs, opts)
  end

  # Resolves points_per_set from attrs (for new sets): loads the match and its group if needed.
  defp resolve_points_per_set(attrs) do
    match_id = attrs[:match_id] || attrs["match_id"]
    resolve_points_per_set_from_match_id(match_id)
  end

  # Resolves points_per_set for an existing set (update): uses the set's match.
  defp resolve_points_per_set_for_set(%MatchSet{} = match_set, attrs) do
    match_id = attrs[:match_id] || attrs["match_id"] || match_set.match_id
    resolve_points_per_set_from_match_id(match_id)
  end

  defp resolve_points_per_set_from_match_id(nil), do: nil

  defp resolve_points_per_set_from_match_id(match_id) do
    match = Repo.get(Match, match_id) |> Repo.preload(:group)

    cond do
      match && match.group_id && match.group -> match.group.points_per_set
      match && match.points_per_set -> match.points_per_set
      true -> nil
    end
  end
end
