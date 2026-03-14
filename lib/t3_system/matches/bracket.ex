defmodule T3System.Matches.Bracket do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          event_id: pos_integer(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "brackets" do
    field :name, :string

    belongs_to :event, Event

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :event_id]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(bracket, attrs) do
    bracket
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:event)
  end
end
