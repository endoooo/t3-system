defmodule T3System.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:tables) do
      add :name, :text, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tables, [:event_id])

    alter table(:matches) do
      add :table_id, references(:tables, on_delete: :nilify_all)
    end
  end
end
