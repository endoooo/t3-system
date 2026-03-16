defmodule T3System.Registrations.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Clubs.Club
  alias T3System.Events.Event
  alias T3System.Matches.Match
  alias T3System.Players.Player

  @type t :: %__MODULE__{
          id: pos_integer(),
          player_id: pos_integer(),
          event_id: pos_integer(),
          club_id: pos_integer(),
          category_id: pos_integer(),
          player: Player.t() | Ecto.Association.NotLoaded.t(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          club: Club.t() | Ecto.Association.NotLoaded.t(),
          category: Category.t() | Ecto.Association.NotLoaded.t(),
          matches_as_registration1: [Match.t()] | Ecto.Association.NotLoaded.t(),
          matches_as_registration2: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "registrations" do
    belongs_to :player, Player
    belongs_to :event, Event
    belongs_to :club, Club
    belongs_to :category, Category

    has_many :matches_as_registration1, Match, foreign_key: :registration1_id
    has_many :matches_as_registration2, Match, foreign_key: :registration2_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:player_id, :event_id, :club_id, :category_id]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:player)
    |> assoc_constraint(:event)
    |> assoc_constraint(:club)
    |> assoc_constraint(:category)
    |> unique_constraint([:player_id, :event_id, :category_id])
  end
end
