defmodule T3System.Matches.MatchPlayer do
  @moduledoc """
  A player on one side (1 or 2) of a match inside a team match. The player
  belongs to that side's team; see `T3System.Matches.Match.inner_match_changeset/3`.
  """
  use Ecto.Schema

  alias T3System.Matches.Match
  alias T3System.Players.Player

  @type t :: %__MODULE__{
          id: pos_integer(),
          match_id: pos_integer(),
          player_id: pos_integer(),
          side: 1 | 2,
          match: Match.t() | Ecto.Association.NotLoaded.t(),
          player: Player.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "match_players" do
    field :side, :integer

    belongs_to :match, Match
    belongs_to :player, Player

    timestamps(type: :utc_datetime)
  end
end
