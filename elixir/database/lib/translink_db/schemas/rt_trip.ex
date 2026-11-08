defmodule TranslinkDb.Schemas.RtTrip do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "rt_trip" do
    belongs_to(:trip, TranslinkDb.Schemas.Trip, primary_key: true)
    field(:date, :date, primary_key: true)

    field(:cancelled, :boolean, default: false)
    field(:delay, :integer, default: 0)
  end
end
