defmodule T3System.Players.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          birthdate: Date.t(),
          picture_url: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "players" do
    field :name, :string
    field :birthdate, :date
    field :picture_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :birthdate, :picture_url])
    |> validate_required([:name, :birthdate])
  end
end
