alias TranslinkDb.Repo
alias TranslinkDb.Schema.{RtTrip, RtStopTime}
alias TranslinkDb.Data.Type
alias TranslinkDb.Util.Batch
import Ecto.Query

defmodule TranslinkDb.Data.Realtime.DB do
  @moduledoc "Util module for direct DB queries for realtime data"

  @spec get_updates(Date.t()) :: Type.updates()
  def get_updates(date) do
    from(
      trip in RtTrip,
      join: stop in RtStopTime,
      on: trip.trip_id == stop.trip_id and trip.date == stop.date,
      group_by: [trip.trip_id, trip.cancelled],
      where: trip.date == ^date,
      select: {
        trip.trip_id,
        trip.cancelled |> coalesce(false),
        "array_agg(?)" |> fragment(stop.stop_sequence),
        "array_agg(?)" |> fragment(stop.skipped |> coalesce(false)),
        "array_agg(?)" |> fragment(stop.arrival_delay |> coalesce(0)),
        "array_agg(?)" |> fragment(stop.departure_delay |> coalesce(0))
      }
    )
    |> Repo.all()
    |> Map.new(fn {trip_id, cancelled, stop_seqs, stop_skippeds, arrival_delays, departure_delays} ->
      {
        trip_id,
        %{
          cancelled: cancelled,
          stops:
            [
              stop_seqs,
              stop_skippeds,
              arrival_delays,
              departure_delays
            ]
            |> Enum.zip_with(
              &{&1 |> Enum.at(0),
               %{
                 skipped: &1 |> Enum.at(1),
                 arrival_delay: &1 |> Enum.at(2),
                 departure_delay: &1 |> Enum.at(3)
               }}
            )
            |> Map.new()
        }
      }
    end)
  end

  @spec update_trips(Date.t(), Type.trips_cancelled?()) :: any()
  def update_trips(date, trips_cancelled) do
    opts = [
      on_conflict: :replace_all,
      conflict_target: [:trip_id, :date]
    ]

    trips_cancelled
    |> Enum.map(fn {trip_id, cancelled} ->
      %{
        trip_id: trip_id,
        date: date,
        cancelled: cancelled
      }
    end)
    |> then(&Batch.insert_all(RtTrip, &1, opts))
  end

  @spec update_stops(Date.t(), Type.stops_status()) :: any()
  def update_stops(date, stops_status) do
    opts = [
      on_conflict: :replace_all,
      conflict_target: [:trip_id, :stop_sequence, :date]
    ]

    stops_status
    |> Enum.flat_map(fn {trip_id, stops} ->
      Enum.map(stops, fn {stop_sequence, update} ->
        Map.merge(update, %{
          date: date,
          trip_id: trip_id,
          stop_sequence: stop_sequence
        })
      end)
    end)
    |> then(&Batch.insert_all(RtStopTime, &1, opts))
  end
end
