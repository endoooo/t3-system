defmodule T3System.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          address: String.t(),
          datetime: DateTime.t(),
          league_id: pos_integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "events" do
    field :name, :string
    field :address, :string
    field :datetime, :utc_datetime
    field :league_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :address, :datetime])
    |> validate_required([:name, :address, :datetime])
  end
end
