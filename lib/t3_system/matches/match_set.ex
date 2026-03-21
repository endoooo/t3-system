defmodule T3System.Matches.MatchSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Matches.Match
  alias T3System.Registrations.Registration

  @type t :: %__MODULE__{
          id: pos_integer(),
          match_id: pos_integer(),
          set_number: pos_integer(),
          score1: non_neg_integer() | nil,
          score2: non_neg_integer() | nil,
          winner_registration_id: pos_integer() | nil,
          match: Match.t() | Ecto.Association.NotLoaded.t(),
          winner: Registration.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "match_sets" do
    field :set_number, :integer
    field :score1, :integer
    field :score2, :integer

    belongs_to :match, Match
    belongs_to :winner, Registration, foreign_key: :winner_registration_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:set_number]
  @optional_fields [:match_id, :score1, :score2, :winner_registration_id]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(match_set, attrs) do
    match_set
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:set_number, greater_than: 0)
    |> validate_number(:score1, greater_than_or_equal_to: 0)
    |> validate_number(:score2, greater_than_or_equal_to: 0)
    |> assoc_constraint(:match)
    |> assoc_constraint(:winner)
    |> unique_constraint([:match_id, :set_number])
  end
end
