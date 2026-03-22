defmodule T3System.Tables.Table do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event
  alias T3System.Matches.Match

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          event_id: pos_integer(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          matches: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "tables" do
    field :name, :string

    belongs_to :event, Event
    has_many :matches, Match

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(table, attrs) do
    table
    |> cast(attrs, [:name, :event_id])
    |> validate_required([:name, :event_id])
    |> assoc_constraint(:event)
  end
end
