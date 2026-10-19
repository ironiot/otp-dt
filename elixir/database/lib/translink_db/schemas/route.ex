defmodule TranslinkDb.Schemas.Route do
  use Ecto.Schema

  schema "route" do
    field(:name, :string)

    has_many(:trips, TranslinkDb.Schemas.Trip)
  end
end
