defmodule T3System.Matches.Bracket do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Matches.Match
  alias T3System.Matches.Stage

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          rounds: pos_integer(),
          stage_id: pos_integer(),
          stage: Stage.t() | Ecto.Association.NotLoaded.t(),
          matches: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "brackets" do
    field :name, :string
    field :rounds, :integer

    belongs_to :stage, Stage
    has_many :matches, Match

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :stage_id, :rounds]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(bracket, attrs) do
    bracket
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:rounds, greater_than: 0, less_than_or_equal_to: 7)
    |> assoc_constraint(:stage)
  end
end
