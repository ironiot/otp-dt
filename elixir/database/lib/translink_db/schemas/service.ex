defmodule TranslinkDb.Schemas.Service do
  use Ecto.Schema

  schema "service" do
    field(:date, :date)

    has_many(:trips, TranslinkDb.Schemas.Trip)
  end
end
