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
  Creates a bracket. Requires a superuser scope.

  ## Examples

      iex> create_bracket(superuser_scope, %{field: value})
      {:ok, %Bracket{}}

      iex> create_bracket(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_bracket(%Scope{user: %{role: "superuser"}}, attrs) do
    %Bracket{}
    |> Bracket.changeset(attrs)
    |> Repo.insert()
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

  ## Examples

      iex> update_match(superuser_scope, match, %{field: new_value})
      {:ok, %Match{}}

      iex> update_match(non_superuser_scope, match, %{field: value})
      ** (FunctionClauseError)

  """
  def update_match(%Scope{user: %{role: "superuser"}}, %Match{} = match, attrs) do
    match
    |> Match.changeset(attrs)
    |> Repo.update()
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

    if match_id do
      match = Repo.get(Match, match_id) |> Repo.preload(:group)

      cond do
        match && match.group_id && match.group ->
          match.group.points_per_set

        match && match.points_per_set ->
          match.points_per_set

        true ->
          nil
      end
    end
  end

  # Resolves points_per_set for an existing set (update): uses the set's match.
  defp resolve_points_per_set_for_set(%MatchSet{} = match_set, attrs) do
    match_id = attrs[:match_id] || attrs["match_id"] || match_set.match_id

    if match_id do
      match = Repo.get(Match, match_id) |> Repo.preload(:group)

      cond do
        match && match.group_id && match.group ->
          match.group.points_per_set

        match && match.points_per_set ->
          match.points_per_set

        true ->
          nil
      end
    end
  end
end
