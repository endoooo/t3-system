defmodule T3System.Repo.Migrations.AddCategoryAndQualifiesCountToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :category_id, references(:categories, on_delete: :restrict), null: false
      add :qualifies_count, :integer, default: 2, null: false
    end

    create index(:groups, [:category_id])
  end
end
