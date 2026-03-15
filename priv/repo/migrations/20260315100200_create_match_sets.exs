defmodule T3System.Repo.Migrations.CreateMatchSets do
  use Ecto.Migration

  def change do
    create table(:match_sets) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false
      add :set_number, :integer, null: false
      add :score1, :integer
      add :score2, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:match_sets, [:match_id])
    create unique_index(:match_sets, [:match_id, :set_number])
  end
end
