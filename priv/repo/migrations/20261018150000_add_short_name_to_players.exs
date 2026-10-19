defmodule T3System.Repo.Migrations.AddShortNameToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :short_name, :text
    end
  end
end
