defmodule T3System.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          format: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "categories" do
    field :name, :string
    field :format, :string, default: "singles"

    timestamps(type: :utc_datetime)
  end

  @formats ~w(singles doubles)

  @doc "The allowed format values."
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :format])
    |> validate_required([:name, :format])
    |> validate_inclusion(:format, @formats)
  end
end
