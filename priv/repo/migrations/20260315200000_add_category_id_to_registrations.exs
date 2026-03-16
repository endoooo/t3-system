defmodule T3System.Repo.Migrations.AddCategoryIdToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:registrations) do
      add :category_id, references(:categories, on_delete: :restrict), null: false
    end

    create index(:registrations, [:category_id])
  end
end
