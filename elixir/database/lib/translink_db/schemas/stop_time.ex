defmodule TranslinkDb.Schemas.StopTime do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "stop_time" do
    belongs_to(:trip, TranslinkDb.Schemas.Trip, primary_key: true)
    field(:stop_sequence, :integer, primary_key: true)

    belongs_to(:stop, TranslinkDb.Schemas.Stop)

    # In seconds from start of service day
    field(:arrival, :integer)
    field(:departure, :integer)

    field(:pickup, :boolean)
    field(:dropoff, :boolean)
  end
end
