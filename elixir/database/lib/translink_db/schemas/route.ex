defmodule TranslinkDb.Schemas.Route do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "route" do
    field(:name, :string)

    has_many(:trips, TranslinkDb.Schemas.Trip)
  end
end
