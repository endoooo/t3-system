defmodule T3System.Registrations do
  @moduledoc """
  The Registrations context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category
  alias T3System.Events
  alias T3System.Registrations.Registration
  alias T3System.Registrations.RegistrationPlayer

  @players_preload [registration_players: [:player, :club]]

  @doc """
  Returns the list of registrations.

  ## Examples

      iex> list_registrations()
      [%Registration{}, ...]

  """
  def list_registrations do
    Repo.all(Registration) |> Repo.preload([:event, :category | @players_preload])
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
    Repo.get!(Registration, id) |> Repo.preload([:event, :category | @players_preload])
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
    |> changeset(attrs)
    |> Repo.insert()
    |> broadcast_change()
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
    Repo.transact(fn ->
      registration
      |> replace_players(attrs)
      |> changeset(drop_player_ids(attrs))
      |> Repo.update()
    end)
    |> broadcast_change()
  end

  # Editing replaces the registration's players: when new players are given,
  # the current rows are deleted first and the given ones inserted. Updating
  # rows in place could swap players or positions between existing rows, which
  # would hit the (non-deferred) unique indexes mid-save. Matches, groups and
  # final standing belong to the registration, so they are untouched.
  defp replace_players(registration, attrs) do
    if players_key(attrs) do
      Repo.delete_all(
        from rp in RegistrationPlayer, where: rp.registration_id == ^registration.id
      )

      %{registration | registration_players: []}
    else
      registration
    end
  end

  defp drop_player_ids(attrs) do
    case players_key(attrs) do
      nil -> attrs
      key -> Map.update!(attrs, key, &drop_ids/1)
    end
  end

  defp players_key(attrs) do
    Enum.find([:registration_players, "registration_players"], &Map.has_key?(attrs, &1))
  end

  defp drop_ids(rows) when is_list(rows), do: Enum.map(rows, &drop_id/1)
  defp drop_ids(%{} = rows), do: Map.new(rows, fn {index, row} -> {index, drop_id(row)} end)
  defp drop_ids(rows), do: rows

  defp drop_id(%{} = row), do: Map.drop(row, [:id, "id"])
  defp drop_id(row), do: row

  @doc """
  Deletes a registration. Requires a superuser scope.

  ## Examples

      iex> delete_registration(superuser_scope, registration)
      {:ok, %Registration{}}

      iex> delete_registration(non_superuser_scope, registration)
      ** (FunctionClauseError)

  """
  def delete_registration(%Scope{user: %{role: "superuser"}}, %Registration{} = registration) do
    registration
    |> Repo.delete()
    |> broadcast_change()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Ecto.Changeset{data: %Registration{}}

  """
  def change_registration(%Registration{} = registration, attrs \\ %{}) do
    changeset(registration, attrs)
  end

  # The registration changeset plus the player rules of its category's format
  # (singles: 1 player, doubles: 2 different players).
  defp changeset(registration, attrs) do
    changeset = Registration.changeset(registration, attrs)
    Registration.validate_players(changeset, category_format(changeset))
  end

  defp category_format(changeset) do
    case Ecto.Changeset.get_field(changeset, :category_id) do
      nil -> nil
      id -> Repo.one(from c in Category, where: c.id == ^id, select: c.format)
    end
  end

  @doc """
  Returns the set of player IDs already registered for a given event and
  category, in any position of any registration.
  """
  def list_registered_player_ids(event_id, category_id) do
    RegistrationPlayer
    |> join(:inner, [rp], r in assoc(rp, :registration))
    |> where([_rp, r], r.event_id == ^event_id and r.category_id == ^category_id)
    |> select([rp], rp.player_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns registrations for a given event and category, with their ordered
  players (each with player and club) and category preloaded. Sorted by final
  standing, then by the first player's name.
  """
  def list_registrations_by_event_and_category(event_id, %Category{id: category_id}) do
    Registration
    |> join(:left, [r], rp in assoc(r, :registration_players), on: rp.position == 1)
    |> join(:left, [_r, rp], p in assoc(rp, :player))
    |> where([r], r.event_id == ^event_id and r.category_id == ^category_id)
    |> order_by([r, _rp, p],
      asc_nulls_last: r.final_standing,
      asc: fragment("? COLLATE \"und-x-icu\"", p.name)
    )
    |> Repo.all()
    |> Repo.preload([:category | @players_preload])
  end

  defp broadcast_change({:ok, %{event_id: event_id}} = result) do
    Events.broadcast_event_updated(event_id)
    result
  end

  defp broadcast_change(result), do: result
end
