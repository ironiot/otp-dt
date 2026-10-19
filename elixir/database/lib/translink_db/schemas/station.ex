defmodule TranslinkDb.Schemas.Station do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "station" do
    field(:name, :string)
    field(:latitude, :float)
    field(:longitude, :float)

    has_many(:stops, TranslinkDb.Schemas.Stop)
  end
end
