defmodule T3System.Repo.Migrations.AddIsOngoingToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :is_ongoing, :boolean, default: false, null: false
    end
  end
end
