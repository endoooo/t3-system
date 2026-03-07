defmodule T3System.Repo do
  use Ecto.Repo,
    otp_app: :t3_system,
    adapter: Ecto.Adapters.Postgres
end
