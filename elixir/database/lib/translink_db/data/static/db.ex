alias TranslinkDb.Repo
alias TranslinkDb.Schema.{Service, Station, StopTime, Stop, StopTransfer, Trip}
alias TranslinkDb.Util.Name
import Ecto.Query

defmodule TranslinkDb.Data.Static.DB do
  @moduledoc "Util module for direct DB queries for static data"

  def walk_edges() do
    # TODO:
    # - Many pairs have a->b distance but not b->a, should be safe to derive.
    # - For others, estimate based on geo-coordinates
    from(
      transfer in StopTransfer,
      group_by: transfer.from_stop_id,
      select: {
        transfer.from_stop_id,
        "array_agg(?)" |> fragment(transfer.to_stop_id),
        "array_agg(?)" |> fragment(transfer.seconds)
      }
    )
    |> Repo.all()
    |> Map.new(fn {from, to_array, dist_array} ->
      {from,
       Enum.zip_with(to_array, dist_array, fn to, dist ->
         %{
           from_stop_id: from,
           to_stop_id: to,
           distance: dist
         }
       end)}
    end)
  end

  def trip_headsigns() do
    from(
      trip in Trip,
      select: {trip.id, trip.headsign}
    )
    |> Repo.all()
    |> Map.new()
  end

  def service_by_date() do
    from(
      service in Service,
      group_by: service.date,
      select: {
        service.date,
        "array_agg(?)" |> fragment(service.id)
      }
    )
    |> Repo.all()
    |> Map.new()
  end

  def stop_names() do
    from(
      stop in Stop,
      select: {stop.id, stop.name}
    )
    |> Repo.all()
    |> Map.new()
  end

  def stop_id_by_code() do
    from(
      stop in Stop,
      select: {stop.code, stop.id}
    )
    |> Repo.all()
    |> Map.new()
  end

  def stop_ids_by_name() do
    by_stop_name = fn ->
      from(
        stop in Stop,
        select: {stop.name, stop.id}
      )
      |> Repo.all()
      |> Enum.group_by(
        fn {name, _} -> Name.normalize(name) end,
        fn {_, stop_id} -> stop_id end
      )
    end

    by_station_name = fn ->
      from(
        stop in Stop,
        join: station in Station,
        on: stop.id == station.id,
        group_by: station.name,
        select: {
          station.name,
          "array_agg(?)" |> fragment(stop.id)
        }
      )
      |> Repo.all()
      |> Map.new(fn {name, stop_ids} -> {Name.normalize(name), stop_ids} end)
    end

    [by_stop_name, by_station_name]
    |> Enum.map(&Task.async/1)
    |> Enum.map(&Task.await/1)
    |> then(fn [map1, map2] ->
      Map.merge(map1, map2, fn _name, list1, list2 -> list1 ++ list2 end)
    end)
  end

  def trip_ids_by_service() do
    from(
      trip in Trip,
      join: service in Service,
      on: trip.service_id == service.id,
      group_by: service.id,
      select: {
        service.id,
        "array_agg(distinct ?)" |> fragment(trip.id)
      }
    )
    |> Repo.all()
    |> Map.new()
  end

  @ride_edge_buckets 256

  def ride_edges_by_service() do
    buckets =
      from(
        trip in Trip,
        windows: [by_id: [order_by: trip.id]],
        select: %{
          trip_id: trip.id,
          bucket: "ntile(?)" |> fragment(^@ride_edge_buckets) |> over(:by_id)
        }
      )

    from(
      row in subquery(buckets),
      group_by: row.bucket,
      select: {min(row.trip_id), max(row.trip_id)}
    )
    |> Repo.all()
    |> Task.async_stream(
      &ride_edges_bucket/1,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce(%{}, &merge_buckets/2)
  end

  defp ride_edges_bucket({from_trip_id, to_trip_id}) do
    # TODO: handle pickup & dropoff flags
    # For now, all stops allow pickup and dropoff

    # Note: No need to specifically handle trip_transfer,
    # they are naturally discovered when searching routes.

    window_query =
      from(
        stop in StopTime,
        join: trip in assoc(stop, :trip),
        where: stop.trip_id >= ^from_trip_id and stop.trip_id <= ^to_trip_id,
        windows: [trip: [partition_by: stop.trip_id, order_by: stop.stop_sequence]],
        select: %{
          service_id: trip.service_id,
          trip_id: stop.trip_id,
          from_stop_id: stop.stop_id,
          from_stop_sequence: stop.stop_sequence,
          from_departure: stop.departure,
          to_stop_id: stop.stop_id |> lead() |> over(:trip),
          to_stop_sequence: stop.stop_sequence |> lead() |> over(:trip),
          to_arrival: stop.arrival |> lead() |> over(:trip)
        }
      )

    from(
      row in subquery(window_query),
      where: not is_nil(row.to_stop_id) and not is_nil(row.to_arrival),
      group_by: [row.service_id, row.from_stop_id],
      select: {
        row.service_id,
        "array_agg(?)" |> fragment(row.trip_id),
        row.from_stop_id,
        "array_agg(?)" |> fragment(row.from_stop_sequence),
        "array_agg(?)" |> fragment(row.from_departure),
        "array_agg(?)" |> fragment(row.to_stop_id),
        "array_agg(?)" |> fragment(row.to_stop_sequence),
        "array_agg(?)" |> fragment(row.to_arrival)
      }
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0))
    |> Map.new(fn {service_id, groups} ->
      {service_id,
       Map.new(groups, fn {_service_id, trip_ids, from_stop_id, from_sequences, departures,
                           to_stop_ids, to_sequences, arrivals} ->
         {from_stop_id,
          Enum.zip_with(
            [trip_ids, from_sequences, departures, to_stop_ids, to_sequences, arrivals],
            &%{
              trip_id: &1 |> Enum.at(0),
              from_stop_id: from_stop_id,
              from_stop_sequence: &1 |> Enum.at(1),
              from_departure: &1 |> Enum.at(2),
              to_stop_id: &1 |> Enum.at(3),
              to_stop_sequence: &1 |> Enum.at(4),
              to_arrival: &1 |> Enum.at(5)
            }
          )}
       end)}
    end)
  end

  defp merge_buckets({:ok, bucket}, acc) do
    Map.merge(bucket, acc, fn _service_id, bucket_stops, acc_stops ->
      Map.merge(bucket_stops, acc_stops, fn _from_stop_id, bucket_rows, acc_rows ->
        bucket_rows ++ acc_rows
      end)
    end)
  end

  defp merge_buckets({:exit, reason}, _acc) do
    raise "ride_edges bucket failed: #{inspect(reason)}"
  end
end
