defmodule TranslinkDb.Schema.RtTrip do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "rt_trip" do
    belongs_to(:trip, TranslinkDb.Schema.Trip, primary_key: true)
    field(:date, :date, primary_key: true)
    field(:cancelled, :boolean, default: false)
  end
end
