defmodule TranslinkDb.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
	create table(:station) do
       	add :name, :string, null: false
       	add :latitude, :float, null: false
        add :longitude, :float, null: false
	end

    # Bus stop, train platform
    create table(:stop) do
     	# The number on bus stop signs,
	    # not present for station platforms,
		# technically not guaranteed unique (though most likely is)
     	add :code, :integer, null: true
      	add :name, :string, null: false
       	# Need geo-coordinates for walking distance
       	add :latitude, :float, null: false
        add :longitude, :float, null: false
        # Each platform in a station has a different stop ID
        add :station_id, references(:station), null: true
	end

	# Bus/train lines. Directions count as the same route.
	create table(:route) do
		add :name, :string, null: false
	end

	# Linked to trip, indicate on which days a route is available
	create table(:service) do
		add :date, :date, null: false
	end

	# An individual run, with direction
	create table(:trip) do
		# e.g. "To UBC Exchange", for UI only
		add :headsign, :string, null: false
		add :route_id, references(:route), null: false
		add :service_id, references(:service), null: false
	end

	create table(:stop_time, primary_key: false) do
		add :trip_id, references(:trip), primary_key: true
		# The index of the stop within a trip
		add :stop_index, :integer, primary_key: true
		# (trip_id, stop_id) is not valid PK,
		# some trips do revisit the same stop
		add :stop_id, references(:stop), null: false
		# In seconds from start of service day
		add :arrival, :integer, null: false
		add :departure, :integer, null: false
		# e.g. terminal stop only has dropoff, no pickup
		add :pickup, :boolean, null: false
		add :dropoff, :boolean, null: false

	end

	# Some pairs of bus stops have an estimated transfer time,
	# use this when available, otherwise infer from geo-coordinates
	create table(:stop_transfer, primary_key: false) do
		add :from_stop_id, references(:stop), primary_key: true
		add :to_stop_id, references(:stop), primary_key: true
		add :seconds, :integer, null: false
	end

	# When you can stay on the same bus when it changes route
	# A trip transfer is equivalent to a stop transfer with
	# from_stop_id == to_stop_id, seconds == 0
	create table(:trip_transfer, primary_key: false) do
		add :from_trip_id, references(:trip), primary_key: true
		add :to_trip_id, references(:trip), primary_key: true
		add :stop_id, references(:stop), null: false
	end
  end
end
