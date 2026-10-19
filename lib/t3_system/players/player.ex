defmodule T3System.Players.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          short_name: String.t() | nil,
          birthdate: Date.t() | nil,
          picture_url: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "players" do
    field :name, :string
    field :short_name, :string
    field :birthdate, :date
    field :picture_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :short_name, :birthdate, :picture_url])
    |> validate_required([:name])
  end

  @doc """
  The player's short name, or one derived from their name when none is set.

  ## Examples

      iex> display_short_name(%Player{name: "Ana Julia Caceres", short_name: nil})
      "A. Caceres"
  """
  @spec display_short_name(t()) :: String.t()
  def display_short_name(%__MODULE__{short_name: short_name}) when is_binary(short_name),
    do: short_name

  def display_short_name(%__MODULE__{name: name}), do: abbreviate_name(name)

  @doc """
  Abbreviates a full name to the first name's initial plus the last name.
  A single name is kept as is.

  ## Examples

      iex> abbreviate_name("Ana Julia Caceres")
      "A. Caceres"

      iex> abbreviate_name("William")
      "William"
  """
  @spec abbreviate_name(String.t() | nil) :: String.t()
  def abbreviate_name(name) do
    case String.split(name || "") do
      [] -> ""
      [single] -> single
      [first | rest] -> "#{String.first(first)}. #{List.last(rest)}"
    end
  end
end
