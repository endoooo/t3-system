defmodule T3System.Repo.Migrations.CreateEventsCategories do
  use Ecto.Migration

  def change do
    create table(:events_categories, primary_key: false) do
      add :event_id, references(:events, on_delete: :delete_all), null: false, primary_key: true

      add :category_id, references(:categories, on_delete: :delete_all),
        null: false,
        primary_key: true
    end

    create index(:events_categories, [:category_id])
  end
end
