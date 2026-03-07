defmodule T3System.Repo.Migrations.RenamePlayerToPlayers do
  use Ecto.Migration

  def change do
    rename table(:player), to: table(:players)
  end
end
