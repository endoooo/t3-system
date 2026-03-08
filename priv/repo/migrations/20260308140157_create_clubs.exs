defmodule T3System.Repo.Migrations.CreateClubs do
  use Ecto.Migration

  def change do
    create table(:clubs) do
      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
