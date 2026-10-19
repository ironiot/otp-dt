defmodule TranslinkDb.Schemas.Service do
  use Ecto.Schema

  @primary_key false

  schema "service" do
    field(:id, :integer, primary_key: true)
    field(:date, :date, primary_key: true)
  end
end
