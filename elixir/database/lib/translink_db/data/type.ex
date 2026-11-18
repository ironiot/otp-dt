defmodule TranslinkDb.Data.Type do
  @type stop_id :: integer()
  @type stop_code :: integer()
  @type seconds :: integer()
  @type trip_id :: integer()
  @type service :: [integer()]
  @type stop_sequence :: integer()

  @type walk_edge :: %{
          from_stop_id: stop_id(),
          to_stop_id: stop_id(),
          distance: seconds()
        }

  @type ride_edge :: %{
          from_stop_id: stop_id(),
          from_stop_sequence: stop_sequence(),
          from_departure: seconds(),
          to_stop_id: stop_id(),
          to_stop_sequence: stop_sequence(),
          to_arrival: seconds(),
          trip_id: trip_id()
        }

  @type trip_cancelled? :: boolean()
  @type trips_cancelled? :: %{trip_id() => trip_cancelled?()}

  @type stop_status :: %{
          skipped: boolean(),
          arrival_delay: seconds(),
          departure_delay: seconds()
        }
  @type stops_status :: %{
          trip_id() => %{stop_sequence() => stop_status()}
        }

  @type updates :: %{
          trip_id() => %{
            cancelled: trip_cancelled?(),
            stops: %{stop_sequence() => stop_status()}
          }
        }
end
