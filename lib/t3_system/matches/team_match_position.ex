defmodule T3System.Matches.TeamMatchPosition do
  @moduledoc """
  A player's position ("A", "X") on one side (1 or 2) of a team match, for the
  whole team match. The player belongs to that side's team; see
  `T3System.Matches.Match.positions_changeset/2`.
  """
  use Ecto.Schema

  alias T3System.Matches.Match
  alias T3System.Players.Player

  @type t :: %__MODULE__{
          id: pos_integer(),
          team_match_id: pos_integer(),
          player_id: pos_integer(),
          side: 1 | 2,
          position: String.t(),
          team_match: Match.t() | Ecto.Association.NotLoaded.t(),
          player: Player.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "team_match_positions" do
    field :side, :integer
    field :position, :string

    belongs_to :team_match, Match
    belongs_to :player, Player

    timestamps(type: :utc_datetime)
  end
end
