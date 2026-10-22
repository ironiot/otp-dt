defmodule TranslinkDb.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:station, primary_key: false) do
      add(:id, :integer, primary_key: true)
      add(:name, :string, null: false)
      add(:latitude, :float, null: false)
      add(:longitude, :float, null: false)
    end

    # Bus stop, train platform
    create table(:stop, primary_key: false) do
      # Internal ID used by translink
      add(:id, :integer, primary_key: true)
      # The number on bus stop signs,
      # not guaranteed unique according to GTFS,
      # but *is* unique for this dataset.
      add(:code, :integer, null: true)
      add(:name, :string, null: false)
      # Need geo-coordinates for walking distance
      add(:latitude, :float, null: false)
      add(:longitude, :float, null: false)
      # Each platform in a station has a different stop ID
      add(:station_id, references(:station, type: :integer), null: true)
    end

    # Linked with trip to indicate on which date a route is available
    create table(:service, primary_key: false) do
      add(:id, :integer, primary_key: true)
      add(:date, :date, primary_key: true)
    end

    # A vehicle run on a particlar route
    # (2 busses with same number arriving the same stop consecutively
    # have different trip ids)
    create table(:trip, primary_key: false) do
      add(:id, :integer, primary_key: true)
      # e.g. "To UBC Exchange", for UI only
      add(:headsign, :string, null: false)
      add(:service_id, :integer, null: false)
    end

    create table(:stop_time, primary_key: false) do
      add(:trip_id, references(:trip, type: :integer), primary_key: true)
      # Think of it like the index of this stop within this trip,
      # although for some reason the numbers have gaps.
      add(:stop_sequence, :integer, primary_key: true)
      # (trip_id, stop_id) is not valid PK,
      # some trips do revisit the same stop
      add(:stop_id, references(:stop, type: :integer), null: false)
      # In seconds from start of service day
      add(:arrival, :integer, null: false)
      add(:departure, :integer, null: false)
      # e.g. terminal stop only has dropoff, no pickup
      add(:pickup, :boolean, null: false)
      add(:dropoff, :boolean, null: false)
    end

    # Some pairs of bus stops have an estimated transfer time,
    # use this when available, otherwise infer from geo-coordinates
    create table(:stop_transfer, primary_key: false) do
      add(:from_stop_id, references(:stop, type: :integer), primary_key: true)
      add(:to_stop_id, references(:stop, type: :integer), primary_key: true)
      add(:seconds, :integer, null: false)
    end

    # When you can stay on the same bus when it changes route
    # A trip transfer is equivalent to a stop transfer with
    # from_stop_id == to_stop_id, seconds == 0
    create table(:trip_transfer, primary_key: false) do
      add(:from_trip_id, references(:trip, type: :integer), primary_key: true)
      add(:to_trip_id, references(:trip, type: :integer), primary_key: true)
      add(:stop_id, references(:stop, type: :integer), null: false)
    end

    create(index(:stop, [:station_id]))
    create(index(:service, [:date]))
    create(index(:trip, [:service_id]))
    create(index(:stop_time, [:stop_id]))
  end
end
