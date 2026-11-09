defmodule TranslinkDb.Data.Type do
  # For readability, it's hard to read when everything is integer

  @type stop_id :: integer()
  @type stop_code :: integer()
  @type seconds :: integer()
  @type trip_id :: integer()
  @type service_id :: integer()
  @type stop_sequence :: integer()

  @type walk_edge :: %{
          from_stop_id: stop_id(),
          to_stop_id: stop_id(),
          distance: seconds()
        }

  @type ride_edge :: %{
          from_stop_id: stop_id(),
          to_stop_id: stop_id(),
          from_departure: seconds(),
          to_arrival: seconds(),
          trip_id: trip_id()
        }

  @type trip_updates :: %{
          trip_id() => %{cancelled: boolean()}
        }

  @type stop_updates :: %{
          {trip_id(), stop_sequence()} => %{
            skipped: boolean(),
            arrival_delay: seconds(),
            departure_delay: seconds()
          }
        }
end
