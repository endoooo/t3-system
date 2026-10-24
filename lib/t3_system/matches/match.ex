defmodule T3System.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.MatchPlayer
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration
  alias T3System.Tables.Table

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          group_id: pos_integer() | nil,
          stage_id: pos_integer() | nil,
          team_match_id: pos_integer() | nil,
          position1: String.t() | nil,
          position2: String.t() | nil,
          kind: String.t() | nil,
          player_ids1: [pos_integer()] | nil,
          player_ids2: [pos_integer()] | nil,
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
    field :position1, :string
    field :position2, :string

    # Lineup form fields of a match inside a team match (see inner_match_changeset/3)
    field :kind, :string, virtual: true
    field :player_ids1, {:array, :integer}, virtual: true
    field :player_ids2, {:array, :integer}, virtual: true

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

    timestamps(type: :utc_datetime)
  end

  @castable_fields [
    :event_id,
    :group_id,
    :stage_id,
    :team_match_id,
    :position1,
    :position2,
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
  The lineup of a match inside `team_match` (whose teams' players are
  preloaded): its kind ("singles": 1 player per side, "doubles": 2 different
  players per side), position labels and each side's players, picked from that
  side's team. The match copies the event and both teams from its team match.
  `player_ids1`/`player_ids2` default to the match's current players
  (`match_players` preloaded when editing).
  """
  @spec inner_match_changeset(t(), t(), map()) :: Ecto.Changeset.t()
  def inner_match_changeset(%__MODULE__{} = match, %__MODULE__{} = team_match, attrs) do
    match
    |> with_lineup_fields()
    |> cast(attrs, [:kind, :position1, :position2, :player_ids1, :player_ids2])
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

    expected =
      case get_field(changeset, :kind) do
        "doubles" -> 2
        _ -> 1
      end

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
end
