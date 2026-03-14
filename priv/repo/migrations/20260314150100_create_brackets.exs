defmodule T3System.Repo.Migrations.CreateBrackets do
  use Ecto.Migration

  def change do
    create table(:brackets) do
      add :name, :text, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:brackets, [:event_id])
  end
end
