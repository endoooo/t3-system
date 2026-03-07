defmodule T3System.Repo.Migrations.CreatePlayer do
  use Ecto.Migration

  def change do
    create table(:player) do
      add :name, :text, null: false
      add :birthdate, :date, null: false
      add :picture_url, :text

      timestamps(type: :utc_datetime)
    end
  end
end
