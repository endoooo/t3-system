defmodule T3System.Repo.Migrations.AddFinalStandingToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:registrations) do
      add :final_standing, :integer
    end
  end
end
