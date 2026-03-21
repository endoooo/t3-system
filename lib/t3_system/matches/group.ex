defmodule T3System.Matches.Group do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Matches.Match
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          qualifies_count: pos_integer(),
          is_finished: boolean(),
          position: integer(),
          stage_id: pos_integer(),
          stage: Stage.t() | Ecto.Association.NotLoaded.t(),
          matches: [Match.t()] | Ecto.Association.NotLoaded.t(),
          registrations: [Registration.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "groups" do
    field :name, :string
    field :qualifies_count, :integer, default: 2
    field :is_finished, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :stage, Stage
    has_many :matches, Match
    many_to_many :registrations, Registration, join_through: "group_registrations"

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :stage_id]
  @optional_fields [:qualifies_count, :is_finished, :position]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(group, attrs) do
    group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:qualifies_count, greater_than: 0)
    |> assoc_constraint(:stage)
  end
end
