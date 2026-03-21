defmodule T3System.Repo.Migrations.RemoveBracketsTable do
  use Ecto.Migration

  def up do
    # Add rounds to stages (only used when type = "bracket")
    alter table(:stages) do
      add :rounds, :integer
    end

    # Add stage_id to matches (for bracket matches, replacing bracket_id)
    alter table(:matches) do
      add :stage_id, references(:stages, on_delete: :delete_all)
    end

    create index(:matches, [:stage_id])

    # Migrate data: copy rounds from brackets to stages, link matches to stages
    execute """
    UPDATE stages
    SET rounds = b.rounds
    FROM brackets b
    WHERE b.stage_id = stages.id
    """

    execute """
    UPDATE matches
    SET stage_id = b.stage_id
    FROM brackets b
    WHERE matches.bracket_id = b.id
    """

    # Drop the old constraint and column
    drop constraint(:matches, :exactly_one_context)

    alter table(:matches) do
      remove :bracket_id
    end

    # Add new constraint: exactly one of group_id or stage_id
    create constraint(:matches, :exactly_one_context,
             check:
               "(group_id IS NOT NULL AND stage_id IS NULL) OR (group_id IS NULL AND stage_id IS NOT NULL)"
           )

    # Drop brackets table
    drop table(:brackets)
  end

  def down do
    # Recreate brackets table
    create table(:brackets) do
      add :name, :text
      add :rounds, :integer
      add :stage_id, references(:stages, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create index(:brackets, [:stage_id])

    # Add bracket_id back to matches
    drop constraint(:matches, :exactly_one_context)

    alter table(:matches) do
      add :bracket_id, references(:brackets, on_delete: :delete_all)
    end

    create index(:matches, [:bracket_id])

    # Migrate data back: create brackets from stages, relink matches
    execute """
    INSERT INTO brackets (name, rounds, stage_id, inserted_at, updated_at)
    SELECT s.name, s.rounds, s.id, s.inserted_at, s.updated_at
    FROM stages s
    WHERE s.type = 'bracket' AND s.rounds IS NOT NULL
    """

    execute """
    UPDATE matches
    SET bracket_id = b.id
    FROM brackets b
    WHERE matches.stage_id = b.stage_id
    """

    alter table(:matches) do
      remove :stage_id
    end

    create constraint(:matches, :exactly_one_context,
             check:
               "(group_id IS NOT NULL AND bracket_id IS NULL) OR (group_id IS NULL AND bracket_id IS NOT NULL)"
           )

    alter table(:stages) do
      remove :rounds
    end
  end
end
