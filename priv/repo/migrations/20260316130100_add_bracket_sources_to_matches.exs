defmodule T3System.Repo.Migrations.AddBracketSourcesToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :source1_group_id, references(:groups, on_delete: :nilify_all)
      add :source1_rank, :integer
      add :source2_group_id, references(:groups, on_delete: :nilify_all)
      add :source2_rank, :integer
    end
  end
end
