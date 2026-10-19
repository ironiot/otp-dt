defmodule TranslinkDb.Schemas.Service do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "service" do
    has_many(:service_dates, TranslinkDb.Schemas.ServiceDate)
    has_many(:trips, TranslinkDb.Schemas.Trip)
  end
end
