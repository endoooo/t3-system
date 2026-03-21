defmodule T3System.Repo.Migrations.SimplifyMatchSets do
  use Ecto.Migration

  def change do
    alter table(:match_sets) do
      add :winner_registration_id, references(:registrations, on_delete: :nilify_all)
    end

    alter table(:matches) do
      remove :best_of, :integer
      remove :points_per_set, :integer
    end

    alter table(:groups) do
      remove :best_of, :integer, default: 5, null: false
      remove :points_per_set, :integer, default: 11, null: false
    end
  end
end
