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

  @type trips_cancelled :: %{
          trip_id() => boolean()
        }

  @type stops_status :: %{
          trip_id() => %{
            stop_sequence() => %{
              skipped: boolean(),
              arrival_delay: seconds(),
              departure_delay: seconds()
            }
          }
        }

  @type trip_status :: %{
          cancelled: boolean(),
          stops: %{
            stop_sequence() => %{
              skipped: boolean(),
              arrival_delay: seconds(),
              departure_delay: seconds()
            }
          }
        }

  @type updates :: %{trip_id() => trip_status()}
end
