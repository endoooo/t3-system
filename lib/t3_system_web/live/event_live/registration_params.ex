defmodule T3SystemWeb.EventLive.RegistrationParams do
  @moduledoc """
  Shapes the event page's registration form params: one player row per
  player of the category's format, keyed by row index ("0", "1").
  """

  alias T3System.Categories.Category
  alias T3System.Registrations.Registration

  @doc """
  Empty player rows for a new registration: one for singles, two for a pair.
  `club_ids` (by row) pre-selects clubs kept from the previous registration.
  """
  @spec new(Category.t(), [String.t() | nil]) :: map()
  def new(%Category{} = category, club_ids) do
    rows =
      for index <- 0..(Category.player_count(category) - 1) do
        {to_string(index),
         %{"position" => to_string(index + 1), "club_id" => Enum.at(club_ids, index)}}
      end

    %{"registration_players" => Map.new(rows)}
  end

  @doc "The params of an existing registration's player rows."
  @spec edit(Registration.t()) :: map()
  def edit(%Registration{registration_players: players}) do
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

    %{"registration_players" => rows}
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
    |> Enum.sort_by(fn {index, _row} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, row} -> row["club_id"] end)
  end
end
