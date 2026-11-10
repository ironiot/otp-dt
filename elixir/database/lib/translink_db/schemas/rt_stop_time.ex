defmodule TranslinkDb.Schema.RtStopTime do
  use Ecto.Schema

  @primary_key false

  schema "rt_stop_time" do
    belongs_to(:trip, TranslinkDb.Schema.Trip, primary_key: true)
    field(:stop_sequence, :integer, primary_key: true)
    field(:date, :date, primary_key: true)

    field(:skipped, :boolean, default: false)
    field(:arrival_delay, :integer)
    field(:departure_delay, :integer)
  end
end
