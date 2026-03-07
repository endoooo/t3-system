defmodule T3System.Events.League do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "leagues" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(league, attrs) do
    league
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
