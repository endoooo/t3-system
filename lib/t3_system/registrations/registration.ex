defmodule T3System.Registrations.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Registrations.RegistrationPlayer

  @type t :: %__MODULE__{
          id: pos_integer(),
          event_id: pos_integer(),
          category_id: pos_integer(),
          name: String.t() | nil,
          event: Event.t() | Ecto.Association.NotLoaded.t(),
          registration_players: [RegistrationPlayer.t()] | Ecto.Association.NotLoaded.t(),
          category: Category.t() | Ecto.Association.NotLoaded.t(),
          final_standing: pos_integer() | nil,
          groups: [Group.t()] | Ecto.Association.NotLoaded.t(),
          matches_as_registration1: [Match.t()] | Ecto.Association.NotLoaded.t(),
          matches_as_registration2: [Match.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "registrations" do
    belongs_to :event, Event
    field :name, :string
    field :final_standing, :integer
    belongs_to :category, Category

    has_many :registration_players, RegistrationPlayer,
      on_replace: :delete,
      preload_order: [asc: :position]

    many_to_many :groups, Group, join_through: "group_registrations"
    has_many :matches_as_registration1, Match, foreign_key: :registration1_id
    has_many :matches_as_registration2, Match, foreign_key: :registration2_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  The preload for a registration's players in position order, each with its
  player and club.
  """
  @spec players_preload() :: keyword()
  def players_preload, do: [registration_players: [:player, :club]]

  @required_fields [:event_id, :category_id]
  @optional_fields [:name, :final_standing]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:final_standing, greater_than: 0)
    |> cast_assoc(:registration_players, required: true)
    |> assoc_constraint(:event)
    |> assoc_constraint(:category)
    # Raised by the trigger that copies a moved registration's event and
    # category onto its players.
    |> unique_constraint(:category_id,
      name: :registration_players_player_id_event_id_category_id_index,
      message: "player already registered in this category"
    )
  end

  @doc """
  Validates the registration against its category's format.

  - singles: exactly 1 player, at position 1, and no name
  - doubles: exactly 2 different players, at positions 1..2, and no name
  - team: a name and at least 1 player, all different, at any position

  A `nil` format (unknown category) skips the check.
  """
  @spec validate_format(Ecto.Changeset.t(), String.t() | nil) :: Ecto.Changeset.t()
  def validate_format(changeset, nil), do: changeset

  def validate_format(changeset, format) do
    changeset
    |> validate_name(format)
    |> validate_positions(format)
    |> validate_players(format)
  end

  defp validate_name(changeset, "team"), do: validate_required(changeset, [:name])

  defp validate_name(changeset, _format) do
    if get_field(changeset, :name) in [nil, ""] do
      changeset
    else
      add_error(changeset, :name, "must be blank outside team categories")
    end
  end

  # Caps each player row's position by format (teams have no upper limit).
  defp validate_positions(changeset, "team"), do: changeset

  defp validate_positions(changeset, format) do
    positions = 1..Category.player_count(format)

    case get_change(changeset, :registration_players) do
      rows when is_list(rows) ->
        rows = Enum.map(rows, &validate_inclusion(&1, :position, positions))
        # `put_change/3` can't take the changesets `cast_assoc` built, so the
        # validated rows go straight into the changes.
        changeset = %{
          changeset
          | changes: Map.put(changeset.changes, :registration_players, rows)
        }

        if Enum.all?(rows, & &1.valid?), do: changeset, else: %{changeset | valid?: false}

      _ ->
        changeset
    end
  end

  defp validate_players(changeset, format) do
    case get_field(changeset, :registration_players) do
      %Ecto.Association.NotLoaded{} -> changeset
      # An empty list is already rejected by `cast_assoc(required: true)`.
      [] -> changeset
      players -> validate_player_list(changeset, format, players)
    end
  end

  defp validate_player_list(changeset, format, players) do
    # Rows without a player (e.g. an unfilled second picker) don't count, so an
    # incomplete pair gets the player-count error.
    player_ids = players |> Enum.map(& &1.player_id) |> Enum.reject(&is_nil/1)

    cond do
      not player_count_valid?(format, length(player_ids)) ->
        add_error(changeset, :registration_players, player_count_message(format))

      length(Enum.uniq(player_ids)) != length(player_ids) ->
        add_error(changeset, :registration_players, duplicate_player_message(format))

      true ->
        changeset
    end
  end

  defp player_count_valid?("team", count), do: count >= 1
  defp player_count_valid?(format, count), do: count == Category.player_count(format)

  defp player_count_message("team"), do: "a team must have at least 1 player"
  defp player_count_message("doubles"), do: "a doubles registration must have exactly 2 players"
  defp player_count_message(_singles), do: "a singles registration must have exactly 1 player"

  defp duplicate_player_message("team"), do: "a team can't have the same player twice"
  defp duplicate_player_message(_doubles), do: "a pair must have two different players"
end
