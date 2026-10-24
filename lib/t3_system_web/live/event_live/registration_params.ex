defmodule T3SystemWeb.EventLive.RegistrationParams do
  @moduledoc """
  Shapes the event page's registration form params: one player row per
  player of the category's format, keyed by row index ("0", "1", ...).
  A team has any number of rows, added and removed by hand.
  """

  alias T3System.Categories.Category
  alias T3System.Registrations.Registration

  # How many player rows a new team starts with.
  @team_rows 3

  @doc """
  Empty player rows for a new registration: one for singles, two for a pair,
  and for a team #{@team_rows} or as many as `club_ids`, whichever is more.
  `club_ids` (by row) pre-selects clubs kept from the previous registration.
  """
  @spec new(Category.t(), [String.t() | nil]) :: map()
  def new(%Category{} = category, club_ids) do
    rows =
      for index <- 0..(row_count(category, club_ids) - 1) do
        {to_string(index), empty_row(index, Enum.at(club_ids, index))}
      end

    %{"registration_players" => Map.new(rows)}
  end

  defp row_count(category, club_ids) do
    if Category.team?(category),
      do: max(@team_rows, length(club_ids)),
      else: Category.player_count(category)
  end

  defp empty_row(index, club_id),
    do: %{"position" => to_string(index + 1), "club_id" => club_id}

  @doc "Appends an empty player row (a team's \"add player\")."
  @spec add_row(map()) :: map()
  def add_row(params) do
    rows = Map.get(params, "registration_players") || %{}
    index = map_size(rows)

    Map.put(
      params,
      "registration_players",
      Map.put(rows, to_string(index), empty_row(index, nil))
    )
  end

  @doc """
  Removes the player row at `index`; the rows after it move up one index and
  position.
  """
  @spec remove_row(map(), String.t()) :: map()
  def remove_row(params, index) do
    rows =
      (params["registration_players"] || %{})
      |> sorted_rows()
      |> Enum.reject(fn {i, _row} -> i == index end)
      |> Enum.with_index()
      |> Map.new(fn {{_i, row}, new_index} ->
        {to_string(new_index), Map.put(row, "position", to_string(new_index + 1))}
      end)

    Map.put(params, "registration_players", rows)
  end

  @doc """
  Drops the combobox selection of the removed row at `index` and moves the
  later rows' selections up one index, like `remove_row/2`.
  """
  @spec remove_selected_player(map(), String.t()) :: map()
  def remove_selected_player(selected_players, index) do
    removed = String.to_integer(index)

    for {i, selection} <- selected_players,
        i = String.to_integer(i),
        i != removed,
        into: %{},
        do: {to_string(if(i > removed, do: i - 1, else: i)), selection}
  end

  @doc "The params of an existing registration's player rows."
  @spec edit(Registration.t()) :: map()
  def edit(%Registration{registration_players: players, name: name}) do
    rows =
      players
      |> Enum.with_index()
      |> Map.new(fn {rp, index} ->
        {to_string(index),
         %{
           "player_id" => to_string(rp.player_id),
           "club_id" => to_string(rp.club_id),
           "position" => to_string(rp.position)
         }}
      end)

    %{"name" => name, "registration_players" => rows}
  end

  @doc "Sets the player of the row at `index`."
  @spec put_player_id(map(), String.t(), String.t() | pos_integer()) :: map()
  def put_player_id(params, index, id) do
    rows = Map.get(params, "registration_players") || %{}
    row = rows |> Map.get(index, %{}) |> Map.put("player_id", to_string(id))
    Map.put(params, "registration_players", Map.put(rows, index, row))
  end

  @doc """
  Merges every combobox selection (`%{index => %{id: id}}`) into the params.
  The comboboxes push their selection outside the form, so submitted params
  lack it.
  """
  @spec put_selected_players(map(), %{String.t() => %{id: String.t()}}) :: map()
  def put_selected_players(params, selected_players) do
    Enum.reduce(selected_players, params, fn {index, %{id: id}}, acc ->
      put_player_id(acc, index, id)
    end)
  end

  @doc "The submitted club of each row, in row order."
  @spec club_ids(map()) :: [String.t() | nil]
  def club_ids(params) do
    (params["registration_players"] || %{})
    |> sorted_rows()
    |> Enum.map(fn {_index, row} -> row["club_id"] end)
  end

  defp sorted_rows(rows), do: Enum.sort_by(rows, fn {index, _row} -> String.to_integer(index) end)
end
