defmodule T3System.Repo.Migrations.SimplifyMatchConnections do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :next_match_id
      remove :source1_group_id
      remove :source1_rank
      remove :source2_group_id
      remove :source2_rank
      add :slot1_label, :text
      add :slot2_label, :text
    end
  end
end
