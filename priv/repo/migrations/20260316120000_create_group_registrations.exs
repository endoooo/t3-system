defmodule T3System.Repo.Migrations.CreateGroupRegistrations do
  use Ecto.Migration

  def change do
    create table(:group_registrations) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :registration_id, references(:registrations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:group_registrations, [:group_id, :registration_id])
    create index(:group_registrations, [:registration_id])
  end
end
