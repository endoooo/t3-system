defmodule T3System.Clubs.Club do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "clubs" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
