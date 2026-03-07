defmodule T3System.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :text, null: false
      add :address, :text, null: false
      add :datetime, :utc_datetime, null: false
      add :league_id, references(:leagues, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:events, [:league_id])
  end
end
