defmodule T3System.Matches.MatchSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias T3System.Matches.Match

  @type t :: %__MODULE__{
          id: pos_integer(),
          match_id: pos_integer(),
          set_number: pos_integer(),
          score1: non_neg_integer() | nil,
          score2: non_neg_integer() | nil,
          match: Match.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "match_sets" do
    field :set_number, :integer
    field :score1, :integer
    field :score2, :integer

    belongs_to :match, Match

    timestamps(type: :utc_datetime)
  end

  @required_fields [:match_id, :set_number]
  @optional_fields [:score1, :score2]

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map(), keyword()) :: Ecto.Changeset.t()
  def changeset(match_set, attrs, opts \\ []) do
    points_per_set = Keyword.get(opts, :points_per_set)

    match_set
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:set_number, greater_than: 0)
    |> validate_number(:score1, greater_than_or_equal_to: 0)
    |> validate_number(:score2, greater_than_or_equal_to: 0)
    |> assoc_constraint(:match)
    |> unique_constraint([:match_id, :set_number])
    |> validate_set_score(points_per_set)
  end

  defp validate_set_score(changeset, nil), do: changeset

  defp validate_set_score(changeset, points_per_set) do
    score1 = get_field(changeset, :score1)
    score2 = get_field(changeset, :score2)

    if is_nil(score1) or is_nil(score2) do
      changeset
    else
      validate_complete_set_score(changeset, score1, score2, points_per_set)
    end
  end

  defp validate_complete_set_score(changeset, score1, score2, points_per_set) do
    max_score = max(score1, score2)
    min_score = min(score1, score2)

    if max_score >= points_per_set do
      validate_winning_score(changeset, max_score, min_score, points_per_set)
    else
      changeset
    end
  end

  defp validate_winning_score(changeset, max_score, min_score, points_per_set) do
    if min_score >= points_per_set - 1 do
      validate_deuce_score(changeset, max_score, min_score)
    else
      validate_normal_win_score(changeset, max_score, points_per_set)
    end
  end

  defp validate_deuce_score(changeset, max_score, min_score) do
    if max_score - min_score >= 2 do
      changeset
    else
      add_error(changeset, :score1, "deuce: winner needs a 2-point lead")
    end
  end

  defp validate_normal_win_score(changeset, max_score, points_per_set) do
    if max_score == points_per_set do
      changeset
    else
      add_error(changeset, :score1, "winner cannot exceed #{points_per_set} points outside deuce")
    end
  end
end
