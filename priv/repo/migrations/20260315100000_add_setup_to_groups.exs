defmodule T3System.Repo.Migrations.AddSetupToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :best_of, :integer, null: false, default: 5
      add :points_per_set, :integer, null: false, default: 11
    end
  end
end
