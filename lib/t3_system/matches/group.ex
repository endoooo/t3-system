defmodule T3System.Matches.Group do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          best_of: pos_integer(),
          points_per_set: pos_integer(),
          event_id: pos_integer(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "groups" do
    field :name, :string
    field :best_of, :integer, default: 5
    field :points_per_set, :integer, default: 11

    belongs_to :event, Event

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :event_id]
  @optional_fields [:best_of, :points_per_set]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(group, attrs) do
    group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:best_of, greater_than: 0)
    |> validate_number(:points_per_set, greater_than: 0)
    |> assoc_constraint(:event)
  end
end
