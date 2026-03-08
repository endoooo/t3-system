defmodule T3System.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
