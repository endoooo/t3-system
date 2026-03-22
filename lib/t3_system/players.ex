defmodule T3System.Players do
  @moduledoc """
  The Players context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Players.Player

  @doc """
  Returns the list of player.

  ## Examples

      iex> list_player()
      [%Player{}, ...]

  """
  def list_player do
    Player
    |> order_by(:name)
    |> Repo.all()
  end

  @doc """
  Gets a single player.

  Raises `Ecto.NoResultsError` if the Player does not exist.

  ## Examples

      iex> get_player!(123)
      %Player{}

      iex> get_player!(456)
      ** (Ecto.NoResultsError)

  """
  def get_player!(id), do: Repo.get!(Player, id)

  @doc """
  Creates a player. Requires a superuser scope.

  ## Examples

      iex> create_player(superuser_scope, %{field: value})
      {:ok, %Player{}}

      iex> create_player(non_superuser_scope, %{field: value})
      {:error, :unauthorized}

  """
  def create_player(%Scope{user: %{role: "superuser"}}, attrs) do
    %Player{}
    |> Player.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a player. Requires a superuser scope.

  ## Examples

      iex> update_player(superuser_scope, player, %{field: new_value})
      {:ok, %Player{}}

      iex> update_player(non_superuser_scope, player, %{field: value})
      {:error, :unauthorized}

  """
  def update_player(%Scope{user: %{role: "superuser"}}, %Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a player. Requires a superuser scope.

  ## Examples

      iex> delete_player(superuser_scope, player)
      {:ok, %Player{}}

      iex> delete_player(non_superuser_scope, player)
      {:error, :unauthorized}

  """
  def delete_player(%Scope{user: %{role: "superuser"}}, %Player{} = player) do
    Repo.delete(player)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking player changes.

  ## Examples

      iex> change_player(player)
      %Ecto.Changeset{data: %Player{}}

  """
  def change_player(%Player{} = player, attrs \\ %{}) do
    Player.changeset(player, attrs)
  end
end
