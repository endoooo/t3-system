defmodule T3System.Repo.Migrations.AddTeamMatchPositions do
  @moduledoc """
  Positions move from each match inside a team match to the team match: each
  team's players get a position for the whole team match, and a match's side
  label comes from the positions of the players on that side.
  """
  use Ecto.Migration

  def up do
    create table(:team_match_positions) do
      add :team_match_id, references(:matches, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :restrict), null: false
      add :side, :integer, null: false
      add :position, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_match_positions, [:team_match_id, :side, :player_id])
    create index(:team_match_positions, [:player_id])

    create constraint(:team_match_positions, :team_match_positions_side, check: "side IN (1, 2)")

    # Deferred, so swapping two players' positions in one save doesn't trip it
    execute """
    ALTER TABLE team_match_positions
    ADD CONSTRAINT team_match_positions_side_position
    UNIQUE (team_match_id, side, position) DEFERRABLE INITIALLY DEFERRED
    """

    alter table(:matches) do
      remove :position1
      remove :position2
    end
  end

  def down do
    alter table(:matches) do
      add :position1, :text
      add :position2, :text
    end

    drop table(:team_match_positions)
  end
end
