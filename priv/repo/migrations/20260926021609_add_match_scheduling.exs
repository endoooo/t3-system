defmodule T3System.Repo.Migrations.AddMatchScheduling do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :match_duration_minutes, :integer, null: false, default: 20
    end

    alter table(:matches) do
      add :table_position, :integer, null: false, default: 0
    end
  end
end
