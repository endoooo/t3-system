defmodule T3System.Repo.Migrations.AddInnerMatches do
  @moduledoc """
  Matches inside a team match (see ADR-0002): a match points to its team match
  instead of a group or bracket stage, has a free position label per side and
  lists who plays each side in `match_players`.
  """
  use Ecto.Migration

  def up do
    alter table(:matches) do
      add :team_match_id, references(:matches, on_delete: :delete_all)
      add :position1, :text
      add :position2, :text
    end

    create index(:matches, [:team_match_id])

    drop constraint(:matches, :exactly_one_context)

    create constraint(:matches, :exactly_one_context,
             check: "num_nonnulls(group_id, stage_id, team_match_id) = 1"
           )

    create table(:match_players) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :restrict), null: false
      add :side, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:match_players, [:match_id, :side, :player_id])
    create index(:match_players, [:player_id])
    create constraint(:match_players, :match_players_side, check: "side IN (1, 2)")
  end

  def down do
    drop table(:match_players)

    execute "DELETE FROM matches WHERE team_match_id IS NOT NULL"

    drop constraint(:matches, :exactly_one_context)

    create constraint(:matches, :exactly_one_context,
             check:
               "(group_id IS NOT NULL AND stage_id IS NULL) OR (group_id IS NULL AND stage_id IS NOT NULL)"
           )

    alter table(:matches) do
      remove :team_match_id
      remove :position1
      remove :position2
    end
  end
end
