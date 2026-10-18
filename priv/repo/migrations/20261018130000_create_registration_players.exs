defmodule T3System.Repo.Migrations.CreateRegistrationPlayers do
  @moduledoc """
  Moves a registration's player and club into `registration_players` rows.

  Each row also stores its registration's event and category so the database
  can enforce "a player appears at most once per event + category" across
  every position. Those two columns are kept in sync with the parent
  registration by triggers, so the application never writes them.
  """
  use Ecto.Migration

  def up do
    create table(:registration_players) do
      add :registration_id, references(:registrations, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :restrict), null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:registration_players, [:club_id])
    create unique_index(:registration_players, [:registration_id, :position])
    create unique_index(:registration_players, [:player_id, :event_id, :category_id])

    execute """
    CREATE FUNCTION registration_players_copy_registration() RETURNS trigger AS $$
    BEGIN
      SELECT r.event_id, r.category_id INTO NEW.event_id, NEW.category_id
      FROM registrations r WHERE r.id = NEW.registration_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER registration_players_copy_registration
    BEFORE INSERT OR UPDATE ON registration_players
    FOR EACH ROW EXECUTE FUNCTION registration_players_copy_registration()
    """

    execute """
    CREATE FUNCTION registrations_sync_players() RETURNS trigger AS $$
    BEGIN
      UPDATE registration_players
      SET event_id = NEW.event_id, category_id = NEW.category_id
      WHERE registration_id = NEW.id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER registrations_sync_players
    AFTER UPDATE OF event_id, category_id ON registrations
    FOR EACH ROW EXECUTE FUNCTION registrations_sync_players()
    """

    execute """
    INSERT INTO registration_players
      (registration_id, player_id, club_id, event_id, category_id, position, inserted_at, updated_at)
    SELECT id, player_id, club_id, event_id, category_id, 1, inserted_at, updated_at
    FROM registrations
    """

    drop unique_index(:registrations, [:player_id, :event_id, :category_id])

    alter table(:registrations) do
      remove :player_id
      remove :club_id
    end
  end

  def down do
    alter table(:registrations) do
      add :player_id, references(:players, on_delete: :delete_all)
      add :club_id, references(:clubs, on_delete: :delete_all)
    end

    # Restores the position-1 player. Any extra players (doubles) are lost.
    execute """
    UPDATE registrations r
    SET player_id = rp.player_id, club_id = rp.club_id
    FROM registration_players rp
    WHERE rp.registration_id = r.id AND rp.position = 1
    """

    execute "DELETE FROM registrations WHERE player_id IS NULL"

    execute "ALTER TABLE registrations ALTER COLUMN player_id SET NOT NULL"
    execute "ALTER TABLE registrations ALTER COLUMN club_id SET NOT NULL"

    create index(:registrations, [:club_id])
    create unique_index(:registrations, [:player_id, :event_id, :category_id])

    execute "DROP TRIGGER registrations_sync_players ON registrations"
    execute "DROP FUNCTION registrations_sync_players()"
    drop table(:registration_players)
    execute "DROP FUNCTION registration_players_copy_registration()"
  end
end
