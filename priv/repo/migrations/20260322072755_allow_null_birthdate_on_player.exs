defmodule T3System.Repo.Migrations.AllowNullBirthdateOnPlayer do
  use Ecto.Migration

  def change do
    alter table(:players) do
      modify :birthdate, :date, null: true, from: {:date, null: false}
    end
  end
end
