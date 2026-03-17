defmodule T3System.Repo.Migrations.AddCategoryAndRoundsToBrackets do
  use Ecto.Migration

  def change do
    alter table(:brackets) do
      add :category_id, references(:categories, on_delete: :restrict), null: false
      add :rounds, :integer, null: false
    end

    create index(:brackets, [:category_id])
    create unique_index(:brackets, [:event_id, :category_id])
  end
end
