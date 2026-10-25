defmodule T3System.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.MatchPlayer
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Matches.TeamMatchPosition
  alias T3System.Registrations.Registration
  alias T3System.Tables.Table

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          group_id: pos_integer() | nil,
          stage_id: pos_integer() | nil,
          team_match_id: pos_integer() | nil,
          kind: String.t() | nil,
          player_ids1: [pos_integer()] | nil,
          player_ids2: [pos_integer()] | nil,
          positions1: %{optional(String.t()) => String.t()} | nil,
          positions2: %{optional(String.t()) => String.t()} | nil,
          registration1_id: pos_integer() | nil,
          registration2_id: pos_integer() | nil,
          winner_registration_id: pos_integer() | nil,
          slot1_label: String.t() | nil,
          slot2_label: String.t() | nil,
          round: pos_integer() | nil,
          position: pos_integer() | nil,
          scheduled_position: integer(),
          table_id: pos_integer() | nil,
          table_position: integer(),
          is_bye: boolean(),
          is_ongoing: boolean(),
          scheduled_at: DateTime.t() | nil,
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          table: Table.t() | Ecto.Association.NotLoaded.t(),
          group: Group.t() | Ecto.Association.NotLoaded.t(),
          stage: Stage.t() | Ecto.Association.NotLoaded.t(),
          registration1: Registration.t() | Ecto.Association.NotLoaded.t(),
          registration2: Registration.t() | Ecto.Association.NotLoaded.t(),
          winner: Registration.t() | Ecto.Association.NotLoaded.t(),
          sets: [MatchSet.t()] | Ecto.Association.NotLoaded.t(),
          team_match: t() | Ecto.Association.NotLoaded.t() | nil,
          inner_matches: [t()] | Ecto.Association.NotLoaded.t(),
          match_players: [MatchPlayer.t()] | Ecto.Association.NotLoaded.t(),
          player_positions: [TeamMatchPosition.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "matches" do
    field :round, :integer
    field :position, :integer
    field :scheduled_position, :integer, default: 0
    field :table_position, :integer, default: 0
    field :is_bye, :boolean, default: false
    field :is_ongoing, :boolean, default: false
    field :scheduled_at, :utc_datetime
    field :slot1_label, :string
    field :slot2_label, :string

    # Lineup form fields of a match inside a team match (see inner_match_changeset/3)
    field :kind, :string, virtual: true
    field :player_ids1, {:array, :integer}, virtual: true
    field :player_ids2, {:array, :integer}, virtual: true

    # Positions form fields of a team match (see positions_changeset/2)
    field :positions1, {:map, :string}, virtual: true
    field :positions2, {:map, :string}, virtual: true

    belongs_to :event, Event
    belongs_to :table, Table
    belongs_to :group, Group
    belongs_to :stage, Stage
    belongs_to :registration1, Registration
    belongs_to :registration2, Registration
    belongs_to :winner, Registration, foreign_key: :winner_registration_id
    belongs_to :team_match, __MODULE__
    has_many :sets, MatchSet, on_replace: :delete
    has_many :inner_matches, __MODULE__, foreign_key: :team_match_id
    has_many :match_players, MatchPlayer, on_replace: :delete

    has_many :player_positions, TeamMatchPosition,
      foreign_key: :team_match_id,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @castable_fields [
    :event_id,
    :group_id,
    :stage_id,
    :team_match_id,
    :registration1_id,
    :registration2_id,
    :winner_registration_id,
    :is_bye,
    :is_ongoing,
    :slot1_label,
    :slot2_label,
    :round,
    :position,
    :scheduled_position,
    :table_id,
    :table_position,
    :scheduled_at
  ]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(match, attrs) do
    match
    |> cast(attrs, @castable_fields)
    |> validate_required([:event_id])
    |> validate_context()
    |> validate_winner()
    |> clear_ongoing_when_finished()
    |> validate_different_registrations()
    |> cast_assoc(:sets, with: &MatchSet.changeset/2)
    |> validate_set_winners()
    |> assoc_constraint(:event)
    |> assoc_constraint(:table)
    |> assoc_constraint(:group)
    |> assoc_constraint(:stage)
    |> assoc_constraint(:team_match)
    |> assoc_constraint(:registration1)
    |> assoc_constraint(:registration2)
    |> assoc_constraint(:winner)
    |> check_constraint(:group_id, name: :exactly_one_context)
  end

  defp validate_winner(changeset) do
    winner_id = get_field(changeset, :winner_registration_id)

    if is_nil(winner_id) do
      changeset
    else
      reg1_id = get_field(changeset, :registration1_id)
      reg2_id = get_field(changeset, :registration2_id)

      if winner_id == reg1_id or winner_id == reg2_id do
        changeset
      else
        add_error(changeset, :winner_registration_id, "must be one of the match participants")
      end
    end
  end

  # A match is either pending, ongoing or finished: finishing it ends the game
  defp clear_ongoing_when_finished(changeset) do
    if is_nil(get_field(changeset, :winner_registration_id)) do
      changeset
    else
      put_change(changeset, :is_ongoing, false)
    end
  end

  defp validate_different_registrations(changeset) do
    reg1_id = get_field(changeset, :registration1_id)
    reg2_id = get_field(changeset, :registration2_id)

    if not is_nil(reg1_id) and not is_nil(reg2_id) and reg1_id == reg2_id do
      add_error(changeset, :registration2_id, "must be different from player 1")
    else
      changeset
    end
  end

  defp validate_set_winners(changeset) do
    case get_change(changeset, :sets) do
      nil ->
        changeset

      set_changesets ->
        reg1_id = get_field(changeset, :registration1_id)
        reg2_id = get_field(changeset, :registration2_id)
        valid_ids = Enum.reject([reg1_id, reg2_id], &is_nil/1)

        has_invalid =
          Enum.any?(set_changesets, fn set_cs ->
            wid = get_field(set_cs, :winner_registration_id)
            not is_nil(wid) and wid not in valid_ids
          end)

        if has_invalid do
          add_error(changeset, :sets, "set winner must be one of the match participants")
        else
          changeset
        end
    end
  end

  defp validate_context(changeset) do
    contexts =
      Enum.count([:group_id, :stage_id, :team_match_id], &(not is_nil(get_field(changeset, &1))))

    case contexts do
      1 ->
        changeset

      0 ->
        add_error(changeset, :base, "must belong to a group, a bracket stage or a team match")

      _ ->
        add_error(
          changeset,
          :base,
          "must belong to only one of a group, a bracket stage or a team match"
        )
    end
  end

  @kinds ~w(singles doubles)

  @doc """
  How many players each side of a match inside a team match has, by its kind:
  like a category of that format (1 for singles, 2 for doubles); 1 for an
  unknown kind.
  """
  @spec side_player_count(String.t() | nil) :: pos_integer()
  def side_player_count(kind) when kind in @kinds, do: Category.player_count(kind)
  def side_player_count(_kind), do: 1

  @doc """
  The lineup of a match inside `team_match` (whose teams' players are
  preloaded): its kind ("singles": 1 player per side, "doubles": 2 different
  players per side), each side's players, picked from that
  side's team (blank picks are ignored), and its table. The match copies the
  event and both teams from its team match. `player_ids1`/`player_ids2`
  default to the match's current players (`match_players` preloaded when
  editing).

  The `table_id` change is for the form only: `T3System.Matches` takes it out
  and moves the match to that table's queue.
  """
  @spec inner_match_changeset(t(), t(), map()) :: Ecto.Changeset.t()
  def inner_match_changeset(%__MODULE__{} = match, %__MODULE__{} = team_match, attrs) do
    match
    |> with_lineup_fields()
    |> cast(lineup_picks(attrs), [
      :kind,
      :player_ids1,
      :player_ids2,
      :table_id
    ])
    |> put_change(:event_id, team_match.event_id)
    |> put_change(:team_match_id, team_match.id)
    |> put_change(:registration1_id, team_match.registration1_id)
    |> put_change(:registration2_id, team_match.registration2_id)
    |> validate_required([:kind])
    |> validate_inclusion(:kind, @kinds)
    |> validate_side(:player_ids1, team_match.registration1)
    |> validate_side(:player_ids2, team_match.registration2)
    |> put_match_players(match)
    |> check_constraint(:group_id, name: :exactly_one_context)
  end

  # The form posts each side's player selects by index (`%{"0" => id, "1" =>
  # id}`), "" for an empty one; the lineup is the picked ids in select order.
  # Non-index keys (LiveView's `"_unused_0"` for untouched selects) are ignored.
  defp lineup_picks(attrs) do
    Map.new(attrs, fn
      {key, ids} when key in ["player_ids1", "player_ids2", :player_ids1, :player_ids2] ->
        {key, ids |> picks_in_order() |> Enum.reject(&(&1 in [nil, ""]))}

      pair ->
        pair
    end)
  end

  defp picks_in_order(%{} = by_index) do
    picks = for {index, id} <- by_index, {n, ""} <- [Integer.parse(index)], do: {n, id}

    picks
    |> Enum.sort_by(fn {n, _id} -> n end)
    |> Enum.map(fn {_n, id} -> id end)
  end

  defp picks_in_order(ids) when is_list(ids), do: ids
  defp picks_in_order(_ids), do: []

  # Fills the lineup form fields from the match's current players
  defp with_lineup_fields(%__MODULE__{match_players: players} = match) when is_list(players) do
    ids = fn side -> for p <- Enum.sort_by(players, & &1.id), p.side == side, do: p.player_id end
    ids1 = ids.(1)

    %{
      match
      | kind: if(length(ids1) == 2, do: "doubles", else: "singles"),
        player_ids1: ids1,
        player_ids2: ids.(2)
    }
  end

  defp with_lineup_fields(match), do: %{match | kind: match.kind || "singles"}

  defp validate_side(changeset, field, team) do
    ids = get_field(changeset, field) || []

    expected = side_player_count(get_field(changeset, :kind))

    cond do
      length(ids) != expected ->
        add_error(changeset, field, "pick %{count} player(s)", count: expected)

      length(Enum.uniq(ids)) != length(ids) ->
        add_error(changeset, field, "pick different players")

      not Enum.all?(ids, &(&1 in team_player_ids(team))) ->
        add_error(changeset, field, "must be players of this side's team")

      true ->
        changeset
    end
  end

  defp team_player_ids(%{registration_players: players}) when is_list(players),
    do: Enum.map(players, & &1.player_id)

  defp team_player_ids(_team), do: []

  # Keeps the rows of the players who stay on the same side, adds the new ones
  defp put_match_players(%{valid?: false} = changeset, _match), do: changeset

  defp put_match_players(changeset, match) do
    current = if is_list(match.match_players), do: match.match_players, else: []

    players =
      for {field, side} <- [player_ids1: 1, player_ids2: 2],
          id <- get_field(changeset, field) do
        Enum.find(current, &(&1.side == side and &1.player_id == id)) ||
          %MatchPlayer{side: side, player_id: id}
      end

    put_assoc(changeset, :match_players, players)
  end

  @doc """
  The positions of a team match (whose teams' players and `player_positions`
  are preloaded): `positions1`/`positions2` map each side's player ids to their
  position ("A", "X"), for every match inside the team match. A side given
  replaces that side's positions (blank ones are cleared); a side not given
  keeps them. A position is used once per side.
  """
  @spec positions_changeset(t(), map()) :: Ecto.Changeset.t()
  def positions_changeset(%__MODULE__{} = team_match, attrs) do
    team_match
    |> with_positions_fields()
    |> cast(position_picks(attrs), [:positions1, :positions2])
    |> validate_positions(:positions1, team_match.registration1)
    |> validate_positions(:positions2, team_match.registration2)
    |> put_player_positions(team_match)
  end

  # Trims the posted positions and drops non-player keys (LiveView's
  # `"_unused_<id>"` for untouched inputs)
  defp position_picks(attrs) do
    Map.new(attrs, fn
      {key, %{} = positions} when key in ["positions1", "positions2"] ->
        picks =
          for {id, position} <- positions,
              {_n, ""} <- [Integer.parse(id)],
              into: %{},
              do: {id, String.trim(position || "")}

        {key, picks}

      pair ->
        pair
    end)
  end

  # Fills the positions form fields from the team match's current positions
  defp with_positions_fields(%__MODULE__{player_positions: positions} = team_match) do
    by_side = fn side ->
      for p <- positions, p.side == side, into: %{}, do: {to_string(p.player_id), p.position}
    end

    %{team_match | positions1: by_side.(1), positions2: by_side.(2)}
  end

  defp validate_positions(changeset, field, team) do
    positions = get_field(changeset, field) || %{}
    team_ids = team_player_ids(team)
    taken = positions |> Map.values() |> Enum.reject(&(&1 == ""))

    cond do
      not Enum.all?(Map.keys(positions), &(String.to_integer(&1) in team_ids)) ->
        add_error(changeset, field, "must be players of this side's team")

      length(Enum.uniq(taken)) != length(taken) ->
        add_error(changeset, field, "use each position once")

      true ->
        changeset
    end
  end

  # Keeps the rows of the players who keep a position (with the new one), adds
  # the new ones, deletes the cleared ones
  defp put_player_positions(%{valid?: false} = changeset, _team_match), do: changeset

  defp put_player_positions(changeset, team_match) do
    current = team_match.player_positions

    positions =
      for {field, side} <- [positions1: 1, positions2: 2],
          {id, position} <- get_field(changeset, field),
          position != "" do
        player_id = String.to_integer(id)

        case Enum.find(current, &(&1.side == side and &1.player_id == player_id)) do
          nil -> %TeamMatchPosition{side: side, player_id: player_id, position: position}
          row -> change(row, position: position)
        end
      end

    put_assoc(changeset, :player_positions, positions)
  end
end
