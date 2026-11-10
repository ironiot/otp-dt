defmodule TranslinkDb.Schema.Stop do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "stop" do
    field(:code, :integer)
    field(:name, :string)
    field(:latitude, :float)
    field(:longitude, :float)

    belongs_to(:station, TranslinkDb.Schema.Station)

    has_many(:stop_times, TranslinkDb.Schema.StopTime)
    has_many(:trip_transfers, TranslinkDb.Schema.TripTransfer)

    has_many(:outgoing_transfers, TranslinkDb.Schema.StopTransfer, foreign_key: :from_stop_id)
    has_many(:incoming_transfers, TranslinkDb.Schema.StopTransfer, foreign_key: :to_stop_id)
  end
end
