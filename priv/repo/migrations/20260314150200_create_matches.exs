defmodule T3System.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all)
      add :bracket_id, references(:brackets, on_delete: :delete_all)
      add :registration1_id, references(:registrations, on_delete: :nilify_all)
      add :registration2_id, references(:registrations, on_delete: :nilify_all)
      add :next_match_id, references(:matches, on_delete: :nilify_all)
      add :round, :integer
      add :position, :integer
      add :scheduled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:matches, [:event_id])
    create index(:matches, [:group_id])
    create index(:matches, [:bracket_id])

    create constraint(:matches, :exactly_one_context,
             check:
               "(group_id IS NOT NULL AND bracket_id IS NULL) OR (group_id IS NULL AND bracket_id IS NOT NULL)"
           )
  end
end
