defmodule T3System.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :club_id, references(:clubs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:registrations, [:event_id])
    create index(:registrations, [:club_id])
    create unique_index(:registrations, [:player_id, :event_id])
  end
end
