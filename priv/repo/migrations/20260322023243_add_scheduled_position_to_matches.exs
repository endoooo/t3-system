defmodule T3System.Repo.Migrations.AddScheduledPositionToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :scheduled_position, :integer, null: false, default: 0
    end
  end
end
