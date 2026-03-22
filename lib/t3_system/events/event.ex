defmodule T3System.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Events.League
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.Stage
  alias T3System.Tables.Table

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          address: String.t(),
          datetime: DateTime.t(),
          league_id: pos_integer() | nil,
          league: League.t() | Ecto.Association.NotLoaded.t(),
          categories: [Category.t()] | Ecto.Association.NotLoaded.t(),
          stages: [Stage.t()] | Ecto.Association.NotLoaded.t(),
          groups: [Group.t()] | Ecto.Association.NotLoaded.t(),
          matches: [Match.t()] | Ecto.Association.NotLoaded.t(),
          tables: [Table.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "events" do
    field :name, :string
    field :address, :string
    field :datetime, :utc_datetime

    belongs_to :league, League
    many_to_many :categories, Category, join_through: "events_categories", on_replace: :delete
    has_many :stages, Stage
    has_many :groups, through: [:stages, :groups]
    has_many :matches, Match
    has_many :tables, Table

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :address, :datetime, :league_id])
    |> validate_required([:name, :address, :datetime])
  end

  def changeset_with_categories(event, attrs, categories) do
    event
    |> changeset(attrs)
    |> put_assoc(:categories, categories)
  end
end
