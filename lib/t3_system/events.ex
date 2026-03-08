defmodule T3System.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories
  alias T3System.Events.League

  @doc """
  Returns the list of leagues.

  ## Examples

      iex> list_leagues()
      [%League{}, ...]

  """
  def list_leagues do
    Repo.all(League)
  end

  @doc """
  Gets a single league.

  Raises `Ecto.NoResultsError` if the League does not exist.

  ## Examples

      iex> get_league!(123)
      %League{}

      iex> get_league!(456)
      ** (Ecto.NoResultsError)

  """
  def get_league!(id), do: Repo.get!(League, id)

  @doc """
  Creates a league.

  ## Examples

      iex> create_league(superuser_scope, %{field: value})
      {:ok, %League{}}

      iex> create_league(superuser_scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_league(%Scope{user: %{role: "superuser"}}, attrs) do
    %League{}
    |> League.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a league.

  ## Examples

      iex> update_league(superuser_scope, league, %{field: new_value})
      {:ok, %League{}}

      iex> update_league(superuser_scope, league, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_league(%Scope{user: %{role: "superuser"}}, %League{} = league, attrs) do
    league
    |> League.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a league.

  ## Examples

      iex> delete_league(superuser_scope, league)
      {:ok, %League{}}

      iex> delete_league(superuser_scope, league)
      {:error, %Ecto.Changeset{}}

  """
  def delete_league(%Scope{user: %{role: "superuser"}}, %League{} = league) do
    Repo.delete(league)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking league changes.

  ## Examples

      iex> change_league(league)
      %Ecto.Changeset{data: %League{}}

  """
  def change_league(%League{} = league, attrs \\ %{}) do
    League.changeset(league, attrs)
  end

  alias T3System.Events.Event

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  def list_events do
    Repo.all(Event) |> Repo.preload(:categories)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(id), do: Repo.get!(Event, id) |> Repo.preload(:categories)

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(superuser_scope, %{field: value})
      {:ok, %Event{}}

      iex> create_event(superuser_scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(%Scope{user: %{role: "superuser"}}, attrs) do
    %Event{}
    |> Event.changeset_with_categories(attrs, fetch_categories(attrs))
    |> Repo.insert()
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(superuser_scope, event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(superuser_scope, event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Scope{user: %{role: "superuser"}}, %Event{} = event, attrs) do
    event
    |> Repo.preload(:categories)
    |> Event.changeset_with_categories(attrs, fetch_categories(attrs))
    |> Repo.update()
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(superuser_scope, event)
      {:ok, %Event{}}

      iex> delete_event(superuser_scope, event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Scope{user: %{role: "superuser"}}, %Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  defp fetch_categories(attrs) do
    ids =
      attrs
      |> Map.get("category_ids", [])
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    Categories.list_categories_by_ids(ids)
  end
end
