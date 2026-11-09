## Usage

`iex -S mix` starts the app. Every 2 minutes,
it fetches new GTFS realtime data, parses and stores it in local ETS tables.

Users call `TranslinkFetcher.get_trip_updates(trip_id)` and `TranslinkFetcher.get_stop_updates(stop_id)`
and receive only the relevant data to that trip/stop.
These functions block until data arrives (could take upto 2 minutes).

If these functions are called in larger than 2 minutes interval,
multiple updates may be returned. It's the caller's responsibility to handle this.

See `TranslinkDb.Fetcher.Stop` and `TranslinkDb.Fetcher.Trip` for usage.

## Structure of realtime data

See `elixir/database/ERD.svg`
