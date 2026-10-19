defmodule TranslinkDb.Schemas.ServiceDate do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "service_date" do
    belongs_to(:service, TranslinkDb.Schemas.Service, primary_key: true)
    field(:date, :date, primary_key: true)
  end
end
