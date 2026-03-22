defmodule T3System.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration
  alias T3System.Tables.Table

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          group_id: pos_integer() | nil,
          stage_id: pos_integer() | nil,
          registration1_id: pos_integer() | nil,
          registration2_id: pos_integer() | nil,
          winner_registration_id: pos_integer() | nil,
          slot1_label: String.t() | nil,
          slot2_label: String.t() | nil,
          round: pos_integer() | nil,
          position: pos_integer() | nil,
          table_id: pos_integer() | nil,
          scheduled_at: DateTime.t() | nil,
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          table: Table.t() | Ecto.Association.NotLoaded.t(),
          group: Group.t() | Ecto.Association.NotLoaded.t(),
          stage: Stage.t() | Ecto.Association.NotLoaded.t(),
          registration1: Registration.t() | Ecto.Association.NotLoaded.t(),
          registration2: Registration.t() | Ecto.Association.NotLoaded.t(),
          winner: Registration.t() | Ecto.Association.NotLoaded.t(),
          sets: [MatchSet.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "matches" do
    field :round, :integer
    field :position, :integer
    field :scheduled_at, :utc_datetime
    field :slot1_label, :string
    field :slot2_label, :string

    belongs_to :event, Event
    belongs_to :table, Table
    belongs_to :group, Group
    belongs_to :stage, Stage
    belongs_to :registration1, Registration
    belongs_to :registration2, Registration
    belongs_to :winner, Registration, foreign_key: :winner_registration_id
    has_many :sets, MatchSet, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @castable_fields [
    :event_id,
    :group_id,
    :stage_id,
    :registration1_id,
    :registration2_id,
    :winner_registration_id,
    :slot1_label,
    :slot2_label,
    :round,
    :position,
    :table_id,
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
    |> validate_set_winners()
    |> assoc_constraint(:event)
    |> assoc_constraint(:table)
    |> assoc_constraint(:group)
    |> assoc_constraint(:stage)
    |> assoc_constraint(:registration1)
    |> assoc_constraint(:registration2)
    |> assoc_constraint(:winner)
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

  defp validate_set_winners(changeset) do
    case get_change(changeset, :sets) do
      nil ->
        changeset

      set_changesets ->
        reg1_id = get_field(changeset, :registration1_id)
        reg2_id = get_field(changeset, :registration2_id)
        valid_ids = Enum.reject([reg1_id, reg2_id], &is_nil/1)

        has_invalid =
          Enum.any?(set_changesets, fn set_cs ->
            wid = get_field(set_cs, :winner_registration_id)
            not is_nil(wid) and wid not in valid_ids
          end)

        if has_invalid do
          add_error(changeset, :sets, "set winner must be one of the match participants")
        else
          changeset
        end
    end
  end

  defp validate_context(changeset) do
    group_id = get_field(changeset, :group_id)
    stage_id = get_field(changeset, :stage_id)

    case {group_id, stage_id} do
      {nil, nil} ->
        add_error(changeset, :base, "must belong to a group or bracket stage")

      {g, s} when not is_nil(g) and not is_nil(s) ->
        add_error(changeset, :base, "cannot belong to both a group and a bracket stage")

      _ ->
        changeset
    end
  end
end
