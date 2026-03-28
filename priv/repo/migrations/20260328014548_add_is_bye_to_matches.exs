defmodule T3System.Repo.Migrations.AddIsByeToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :is_bye, :boolean, null: false, default: false
    end
  end
end
