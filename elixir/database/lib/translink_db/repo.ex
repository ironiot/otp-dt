defmodule TranslinkDb.Repo do
  use Ecto.Repo,
    otp_app: :translink_db,
    adapter: Ecto.Adapters.Postgres
end
