defmodule T3System.Repo.Migrations.AddTeamsToRegistrations do
  @moduledoc """
  Team registrations: a nullable name (required for team categories, checked
  in the changeset) and any number of players, so the player position check
  becomes "at least 1". The changeset caps positions by format.
  """
  use Ecto.Migration

  def up do
    alter table(:registrations) do
      add :name, :text
    end

    drop constraint(:registration_players, :registration_players_position_range)

    create constraint(:registration_players, :registration_players_position_positive,
             check: "position >= 1"
           )
  end

  def down do
    drop constraint(:registration_players, :registration_players_position_positive)

    create constraint(:registration_players, :registration_players_position_range,
             check: "position IN (1, 2)"
           )

    alter table(:registrations) do
      remove :name
    end
  end
end
