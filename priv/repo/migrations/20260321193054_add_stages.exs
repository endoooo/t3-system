defmodule T3System.Repo.Migrations.AddStages do
  use Ecto.Migration

  def up do
    # 1. Create stages table
    create table(:stages) do
      add :name, :text, null: false
      add :type, :text, null: false
      add :order, :integer, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:stages, [:event_id])
    create unique_index(:stages, [:event_id, :category_id, :order])
    create constraint(:stages, :stage_type_must_be_valid, check: "type IN ('group', 'bracket')")

    # 2. Add stage_id to groups and brackets (nullable initially for data migration)
    alter table(:groups) do
      add :stage_id, references(:stages, on_delete: :delete_all)
    end

    alter table(:brackets) do
      add :stage_id, references(:stages, on_delete: :delete_all)
    end

    # 3. Data migration: create stages for existing groups and brackets
    # For each unique (event_id, category_id) in groups, create a stage
    execute("""
    INSERT INTO stages (name, type, "order", event_id, category_id, inserted_at, updated_at)
    SELECT DISTINCT 'Groups', 'group', 1, event_id, category_id, NOW(), NOW()
    FROM groups
    ON CONFLICT DO NOTHING
    """)

    # For each unique (event_id, category_id) in brackets, create a stage
    execute("""
    INSERT INTO stages (name, type, "order", event_id, category_id, inserted_at, updated_at)
    SELECT DISTINCT 'Knockout', 'bracket',
      CASE WHEN EXISTS (
        SELECT 1 FROM stages s
        WHERE s.event_id = b.event_id AND s.category_id = b.category_id
      ) THEN 2 ELSE 1 END,
      b.event_id, b.category_id, NOW(), NOW()
    FROM brackets b
    ON CONFLICT DO NOTHING
    """)

    # Set stage_id on groups
    execute("""
    UPDATE groups g
    SET stage_id = s.id
    FROM stages s
    WHERE s.event_id = g.event_id
      AND s.category_id = g.category_id
      AND s.name = 'Groups'
    """)

    # Set stage_id on brackets
    execute("""
    UPDATE brackets b
    SET stage_id = s.id
    FROM stages s
    WHERE s.event_id = b.event_id
      AND s.category_id = b.category_id
      AND s.name = 'Knockout'
    """)

    # 4. Make stage_id NOT NULL
    execute("ALTER TABLE groups ALTER COLUMN stage_id SET NOT NULL")
    execute("ALTER TABLE brackets ALTER COLUMN stage_id SET NOT NULL")

    # 5. Remove event_id and category_id from groups
    alter table(:groups) do
      remove :event_id
      remove :category_id
    end

    # 6. Remove event_id and category_id from brackets
    # First drop the unique index that depends on these columns
    drop_if_exists unique_index(:brackets, [:event_id, :category_id])

    alter table(:brackets) do
      remove :event_id
      remove :category_id
    end
  end

  def down do
    # Add back event_id and category_id to groups and brackets
    alter table(:groups) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :category_id, references(:categories, on_delete: :restrict)
    end

    alter table(:brackets) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :category_id, references(:categories, on_delete: :restrict)
    end

    # Populate from stages
    execute("""
    UPDATE groups g
    SET event_id = s.event_id, category_id = s.category_id
    FROM stages s
    WHERE g.stage_id = s.id
    """)

    execute("""
    UPDATE brackets b
    SET event_id = s.event_id, category_id = s.category_id
    FROM stages s
    WHERE b.stage_id = s.id
    """)

    execute("ALTER TABLE groups ALTER COLUMN event_id SET NOT NULL")
    execute("ALTER TABLE groups ALTER COLUMN category_id SET NOT NULL")
    execute("ALTER TABLE brackets ALTER COLUMN event_id SET NOT NULL")
    execute("ALTER TABLE brackets ALTER COLUMN category_id SET NOT NULL")

    create unique_index(:brackets, [:event_id, :category_id])

    # Remove stage_id from groups and brackets
    alter table(:groups) do
      remove :stage_id
    end

    alter table(:brackets) do
      remove :stage_id
    end

    # Drop stages table
    drop table(:stages)
  end
end
