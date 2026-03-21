defmodule T3System.Matches.Stage do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.Match

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          type: String.t(),
          order: pos_integer(),
          rounds: pos_integer() | nil,
          event_id: pos_integer(),
          category_id: pos_integer(),
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          category: Category.t() | Ecto.Association.NotLoaded.t(),
          groups: [Group.t()] | Ecto.Association.NotLoaded.t(),
          matches: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "stages" do
    field :name, :string
    field :type, :string
    field :order, :integer
    field :rounds, :integer

    belongs_to :event, Event
    belongs_to :category, Category
    has_many :groups, Group
    has_many :matches, Match

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :type, :order, :event_id, :category_id]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(stage, attrs) do
    stage
    |> cast(attrs, @required_fields ++ [:rounds])
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, ~w(group bracket))
    |> validate_number(:order, greater_than: 0)
    |> validate_bracket_rounds()
    |> assoc_constraint(:event)
    |> assoc_constraint(:category)
    |> unique_constraint([:event_id, :category_id, :order])
  end

  defp validate_bracket_rounds(changeset) do
    if get_field(changeset, :type) == "bracket" do
      changeset
      |> validate_number(:rounds, greater_than: 0, less_than_or_equal_to: 7)
    else
      changeset
    end
  end
end
