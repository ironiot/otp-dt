defmodule TranslinkDb.Schemas.Trip do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "trip" do
    field(:headsign, :string)

    belongs_to(:route, TranslinkDb.Schemas.Route)
    belongs_to(:service, TranslinkDb.Schemas.Service)

    has_many(:stop_times, TranslinkDb.Schemas.StopTime)

    has_many(:outgoing_trip_transfers, TranslinkDb.Schemas.TripTransfer,
      foreign_key: :from_trip_id
    )

    has_many(:incoming_trip_transfers, TranslinkDb.Schemas.TripTransfer, foreign_key: :to_trip_id)
  end
end
