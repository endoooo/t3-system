defmodule T3System.Repo.Migrations.AddPositionToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :position, :integer, default: 0, null: false
    end
  end
end
