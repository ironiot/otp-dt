alias TranslinkDb.Repo
alias TranslinkDb.Schemas.{Service, Station, StopTime, Stop, StopTransfer, Trip}
alias TranslinkDb.Query.Name
import Ecto.Query

defmodule TranslinkDb.Query.Data.Loader do
  @moduledoc "Util module for all direct DB reads."

  def walk_edges() do
    # TODO:
    # - Many pairs have a->b distance but not b->a, should be safe to derive.
    # - For others, estimate based on geo-coordinates
    from(
      transfer in StopTransfer,
      group_by: transfer.from_stop_id,
      select: {
        transfer.from_stop_id,
        fragment("array_agg(?)", transfer.to_stop_id),
        fragment("array_agg(?)", transfer.seconds)
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

  def date_services() do
    from(
      service in Service,
      group_by: service.date,
      select: {
        service.date,
        fragment("array_agg(?)", service.id)
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
        select: {station.name, fragment("array_agg(?)", stop.id)}
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

  @ride_edge_buckets 256
  @max_concurrency 16

  def ride_edges() do
    buckets =
      from(
        trip in Trip,
        windows: [by_id: [order_by: trip.id]],
        select: %{
          trip_id: trip.id,
          bucket: over(fragment("ntile(?)", ^@ride_edge_buckets), :by_id)
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
      max_concurrency: @max_concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce(%{}, &merge_buckets/2)
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
          to_stop_id: lead(stop.stop_id) |> over(:trip),
          from_departure: stop.departure,
          to_arrival: lead(stop.arrival) |> over(:trip)
        }
      )

    from(
      row in subquery(window_query),
      where: not is_nil(row.to_stop_id) and not is_nil(row.to_arrival),
      group_by: [row.service_id, row.from_stop_id],
      select: {
        row.service_id,
        row.from_stop_id,
        fragment("array_agg(?)", row.trip_id),
        fragment("array_agg(?)", row.to_stop_id),
        fragment("array_agg(?)", row.from_departure),
        fragment("array_agg(?)", row.to_arrival)
      }
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0))
    |> Map.new(fn {service_id, groups} ->
      {service_id,
       Map.new(groups, fn {_service_id, from_stop_id, trip_ids, to_stop_ids, departures, arrivals} ->
         {from_stop_id,
          [trip_ids, to_stop_ids, departures, arrivals]
          |> Enum.zip()
          |> Enum.map(fn {trip_id, to_stop_id, from_departure, to_arrival} ->
            %{
              from_stop_id: from_stop_id,
              trip_id: trip_id,
              to_stop_id: to_stop_id,
              from_departure: from_departure,
              to_arrival: to_arrival
            }
          end)}
       end)}
    end)
  end
end
