defmodule T3System.Registrations.RegistrationPlayer do
  @moduledoc """
  One player of a registration, with the club they represent and a position
  used only for display order.

  The table also stores the registration's event and category (kept in sync by
  database triggers) so a player can appear at most once per event + category,
  in any position. Those columns are not part of this schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Clubs.Club
  alias T3System.Players.Player
  alias T3System.Registrations.Registration

  @type t :: %__MODULE__{
          id: pos_integer(),
          registration_id: pos_integer(),
          player_id: pos_integer(),
          club_id: pos_integer(),
          position: 1..2,
          registration: Registration.t() | Ecto.Association.NotLoaded.t(),
          player: Player.t() | Ecto.Association.NotLoaded.t(),
          club: Club.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "registration_players" do
    belongs_to :registration, Registration
    belongs_to :player, Player
    belongs_to :club, Club
    field :position, :integer

    timestamps(type: :utc_datetime)
  end

  @required_fields [:player_id, :club_id, :position]
  # A pair has at most two players.
  @positions 1..2

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(registration_player, attrs) do
    registration_player
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:position, @positions)
    |> check_constraint(:position,
      name: :registration_players_position_range,
      message: "must be 1 or 2"
    )
    |> assoc_constraint(:player)
    |> assoc_constraint(:club)
    |> unique_constraint(:player_id,
      name: :registration_players_player_id_event_id_category_id_index,
      message: "already registered in this category"
    )
    |> unique_constraint(:position, name: :registration_players_registration_id_position_index)
  end
end
