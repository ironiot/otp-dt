defmodule TranslinkDb.Schemas.TripTransfer do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :integer

  schema "trip_transfer" do
    belongs_to(:from_trip, TranslinkDb.Schemas.Trip,
      foreign_key: :from_trip_id,
      primary_key: true
    )

    belongs_to(:to_trip, TranslinkDb.Schemas.Trip, foreign_key: :to_trip_id, primary_key: true)

    belongs_to(:stop, TranslinkDb.Schemas.Stop)
  end
end
