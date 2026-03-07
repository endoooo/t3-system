defmodule T3System.Repo.Migrations.CreateLeagues do
  use Ecto.Migration

  def change do
    create table(:leagues) do
      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
