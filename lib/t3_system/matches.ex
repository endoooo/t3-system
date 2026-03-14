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
      registration1: [:player],
      registration2: [:player]
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
      registration1: [:player],
      registration2: [:player]
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
end
