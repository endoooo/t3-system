defmodule T3System.Repo.Migrations.AddSetupAndWinnerToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :best_of, :integer
      add :points_per_set, :integer
      add :winner_registration_id, references(:registrations, on_delete: :nilify_all)
    end

    create index(:matches, [:winner_registration_id])
  end
end
