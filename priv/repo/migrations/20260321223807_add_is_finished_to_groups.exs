defmodule T3System.Repo.Migrations.AddIsFinishedToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :is_finished, :boolean, default: false, null: false
    end
  end
end
