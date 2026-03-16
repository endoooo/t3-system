defmodule T3System.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event
  alias T3System.Matches.Bracket
  alias T3System.Matches.Group
  alias T3System.Matches.MatchSet
  alias T3System.Registrations.Registration

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          group_id: pos_integer() | nil,
          bracket_id: pos_integer() | nil,
          registration1_id: pos_integer() | nil,
          registration2_id: pos_integer() | nil,
          winner_registration_id: pos_integer() | nil,
          next_match_id: pos_integer() | nil,
          round: pos_integer() | nil,
          position: pos_integer() | nil,
          best_of: pos_integer() | nil,
          points_per_set: pos_integer() | nil,
          scheduled_at: DateTime.t() | nil,
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          group: Group.t() | Ecto.Association.NotLoaded.t(),
          bracket: Bracket.t() | Ecto.Association.NotLoaded.t(),
          registration1: Registration.t() | Ecto.Association.NotLoaded.t(),
          registration2: Registration.t() | Ecto.Association.NotLoaded.t(),
          winner: Registration.t() | Ecto.Association.NotLoaded.t(),
          next_match: t() | Ecto.Association.NotLoaded.t(),
          sets: [MatchSet.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "matches" do
    field :round, :integer
    field :position, :integer
    field :best_of, :integer
    field :points_per_set, :integer
    field :scheduled_at, :utc_datetime

    belongs_to :event, Event
    belongs_to :group, Group
    belongs_to :bracket, Bracket
    belongs_to :registration1, Registration
    belongs_to :registration2, Registration
    belongs_to :winner, Registration, foreign_key: :winner_registration_id
    belongs_to :next_match, __MODULE__
    has_many :sets, MatchSet, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @castable_fields [
    :event_id,
    :group_id,
    :bracket_id,
    :registration1_id,
    :registration2_id,
    :winner_registration_id,
    :next_match_id,
    :round,
    :position,
    :best_of,
    :points_per_set,
    :scheduled_at
  ]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(match, attrs) do
    match
    |> cast(attrs, @castable_fields)
    |> validate_required([:event_id])
    |> validate_context()
    |> validate_winner()
    |> validate_different_registrations()
    |> cast_assoc(:sets, with: &MatchSet.changeset/2)
    |> validate_number(:best_of, greater_than: 0)
    |> validate_number(:points_per_set, greater_than: 0)
    |> assoc_constraint(:event)
    |> assoc_constraint(:group)
    |> assoc_constraint(:bracket)
    |> assoc_constraint(:registration1)
    |> assoc_constraint(:registration2)
    |> assoc_constraint(:winner)
    |> assoc_constraint(:next_match)
    |> check_constraint(:group_id, name: :exactly_one_context)
  end

  defp validate_winner(changeset) do
    winner_id = get_field(changeset, :winner_registration_id)

    if is_nil(winner_id) do
      changeset
    else
      reg1_id = get_field(changeset, :registration1_id)
      reg2_id = get_field(changeset, :registration2_id)

      if winner_id == reg1_id or winner_id == reg2_id do
        changeset
      else
        add_error(changeset, :winner_registration_id, "must be one of the match participants")
      end
    end
  end

  defp validate_different_registrations(changeset) do
    reg1_id = get_field(changeset, :registration1_id)
    reg2_id = get_field(changeset, :registration2_id)

    if not is_nil(reg1_id) and not is_nil(reg2_id) and reg1_id == reg2_id do
      add_error(changeset, :registration2_id, "must be different from player 1")
    else
      changeset
    end
  end

  defp validate_context(changeset) do
    group_id = get_field(changeset, :group_id)
    bracket_id = get_field(changeset, :bracket_id)

    case {group_id, bracket_id} do
      {nil, nil} ->
        add_error(changeset, :base, "must belong to a group or bracket")

      {g, b} when not is_nil(g) and not is_nil(b) ->
        add_error(changeset, :base, "cannot belong to both a group and a bracket")

      _ ->
        changeset
    end
  end
end
