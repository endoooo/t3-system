defmodule T3System.Repo.Migrations.AddPositionCheckToRegistrationPlayers do
  use Ecto.Migration

  def change do
    create constraint(:registration_players, :registration_players_position_range,
             check: "position IN (1, 2)"
           )
  end
end
