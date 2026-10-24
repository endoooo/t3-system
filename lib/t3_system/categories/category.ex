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

  @formats ~w(singles doubles team)

  @doc "The allowed format values."
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc """
  How many players a registration has in a fixed-size category (or format):
  1 for singles, 2 for doubles. Teams have any number of players, so the
  `team` format has no player count.
  """
  @spec player_count(t() | String.t()) :: pos_integer()
  def player_count(%__MODULE__{format: format}), do: player_count(format)
  def player_count("doubles"), do: 2
  def player_count("singles"), do: 1

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :format])
    |> validate_required([:name, :format])
    |> validate_inclusion(:format, @formats)
  end
end
