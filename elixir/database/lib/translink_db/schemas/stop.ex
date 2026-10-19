defmodule TranslinkDb.Schemas.Stop do
  use Ecto.Schema

  schema "stop" do
    field(:code, :integer)
    field(:name, :string)
    field(:latitude, :float)
    field(:longitude, :float)

    belongs_to(:station, TranslinkDb.Schemas.Station)

    has_many(:stop_times, TranslinkDb.Schemas.StopTime)
    has_many(:trip_transfers, TranslinkDb.Schemas.TripTransfer)

    has_many(:outgoing_stop_transfers, TranslinkDb.Schemas.StopTransfer,
      foreign_key: :from_stop_id
    )

    has_many(:incoming_stop_transfers, TranslinkDb.Schemas.StopTransfer, foreign_key: :to_stop_id)
  end
end
