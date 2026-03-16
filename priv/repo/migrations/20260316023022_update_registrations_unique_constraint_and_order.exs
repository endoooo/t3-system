defmodule T3System.Repo.Migrations.UpdateRegistrationsUniqueConstraintAndOrder do
  use Ecto.Migration

  def change do
    drop unique_index(:registrations, [:player_id, :event_id])
    create unique_index(:registrations, [:player_id, :event_id, :category_id])
  end
end
