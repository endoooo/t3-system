defmodule T3System.Registrations do
  @moduledoc """
  The Registrations context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category
  alias T3System.Registrations.Registration

  @doc """
  Returns the list of registrations.

  ## Examples

      iex> list_registrations()
      [%Registration{}, ...]

  """
  def list_registrations do
    Repo.all(Registration) |> Repo.preload([:player, :event, :club, :category])
  end

  @doc """
  Gets a single registration.

  Raises `Ecto.NoResultsError` if the Registration does not exist.

  ## Examples

      iex> get_registration!(123)
      %Registration{}

      iex> get_registration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_registration!(id) do
    Repo.get!(Registration, id) |> Repo.preload([:player, :event, :club, :category])
  end

  @doc """
  Creates a registration. Requires a superuser scope.

  ## Examples

      iex> create_registration(superuser_scope, %{field: value})
      {:ok, %Registration{}}

      iex> create_registration(non_superuser_scope, %{field: value})
      ** (FunctionClauseError)

  """
  def create_registration(%Scope{user: %{role: "superuser"}}, attrs) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration. Requires a superuser scope.

  ## Examples

      iex> update_registration(superuser_scope, registration, %{field: new_value})
      {:ok, %Registration{}}

      iex> update_registration(non_superuser_scope, registration, %{field: value})
      ** (FunctionClauseError)

  """
  def update_registration(
        %Scope{user: %{role: "superuser"}},
        %Registration{} = registration,
        attrs
      ) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a registration. Requires a superuser scope.

  ## Examples

      iex> delete_registration(superuser_scope, registration)
      {:ok, %Registration{}}

      iex> delete_registration(non_superuser_scope, registration)
      ** (FunctionClauseError)

  """
  def delete_registration(%Scope{user: %{role: "superuser"}}, %Registration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Ecto.Changeset{data: %Registration{}}

  """
  def change_registration(%Registration{} = registration, attrs \\ %{}) do
    Registration.changeset(registration, attrs)
  end

  @doc """
  Returns the set of player IDs already registered for a given event and category.
  """
  def list_registered_player_ids(event_id, category_id) do
    Registration
    |> where([r], r.event_id == ^event_id and r.category_id == ^category_id)
    |> select([r], r.player_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns registrations for a given event and category, with player, club, and category preloaded.
  """
  def list_registrations_by_event_and_category(event_id, %Category{id: category_id}) do
    Registration
    |> join(:inner, [r], p in assoc(r, :player))
    |> where([r], r.event_id == ^event_id and r.category_id == ^category_id)
    |> order_by([_r, p], fragment("? COLLATE \"und-x-icu\"", p.name))
    |> Repo.all()
    |> Repo.preload([:player, :club, :category])
  end
end
