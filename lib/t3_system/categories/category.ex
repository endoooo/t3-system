defmodule T3System.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "categories" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
