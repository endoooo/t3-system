defmodule T3System.Registrations.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Registrations.RegistrationPlayer

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          category_id: pos_integer(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          registration_players: [RegistrationPlayer.t()] | Ecto.Association.NotLoaded.t(),
          category: Category.t() | Ecto.Association.NotLoaded.t(),
          final_standing: pos_integer() | nil,
          groups: [Group.t()] | Ecto.Association.NotLoaded.t(),
          matches_as_registration1: [Match.t()] | Ecto.Association.NotLoaded.t(),
          matches_as_registration2: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "registrations" do
    belongs_to :event, Event
    field :final_standing, :integer
    belongs_to :category, Category

    has_many :registration_players, RegistrationPlayer,
      on_replace: :delete,
      preload_order: [asc: :position]

    many_to_many :groups, Group, join_through: "group_registrations"
    has_many :matches_as_registration1, Match, foreign_key: :registration1_id
    has_many :matches_as_registration2, Match, foreign_key: :registration2_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:event_id, :category_id]
  @optional_fields [:final_standing]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:final_standing, greater_than: 0)
    |> cast_assoc(:registration_players, required: true)
    |> assoc_constraint(:event)
    |> assoc_constraint(:category)
    # Raised by the trigger that copies a moved registration's event and
    # category onto its players.
    |> unique_constraint(:category_id,
      name: :registration_players_player_id_event_id_category_id_index,
      message: "player already registered in this category"
    )
  end
end
