defmodule T3System.Repo.Migrations.AddFormatToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :format, :text, null: false, default: "singles"
    end
  end
end
