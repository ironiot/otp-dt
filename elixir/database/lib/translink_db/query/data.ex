alias TranslinkDb.Repo
alias TranslinkDb.Schemas.{Service, StopTime, Stop, StopTransfer, Trip}
alias TranslinkDb.Query.Data.{Worker, Calculator}
import Ecto.Query

defmodule TranslinkDb.Query.Data do
  @moduledoc "Anything that needs to read DB goes through this module, never use DB directly."

  use DynamicSupervisor

  # just for readability, it's hard to read when everything is integer
  @type stop_id :: integer()
  @type stop_code :: integer()
  @type seconds :: integer()
  @type trip_id :: integer()
  @type service_id :: integer()

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

  @doc "Spawns workers to load all data into `:persistent_term`."
  def load do
    [
      :ride_edges,
      :walk_edges,
      :date_services,
      :trip_headsigns,
      :stop_id_by_code,
      :stop_names
    ]
    |> Enum.map(&Supervisor.child_spec({Worker, &1}, restart: :transient))
    |> Enum.each(&DynamicSupervisor.start_child(__MODULE__, &1))
  end

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec walk_edges(stop_id()) :: [walk_edge()]
  def walk_edges(stop_id) do
    Worker.get(:walk_edges) |> Map.get(stop_id, [])
  end

  @spec date_services(Date.t()) :: [service_id()]
  def date_services(date) do
    Worker.get(:date_services) |> Map.get(date, [])
  end

  @spec trip_headsign(trip_id()) :: String.t() | nil
  def trip_headsign(trip_id) do
    Worker.get(:trip_headsigns) |> Map.get(trip_id, nil)
  end

  @spec ride_edges([service_id()], stop_id()) :: [ride_edge()]
  def ride_edges(date_services, stop_id) do
    edges_by_service = Worker.get(:ride_edges)

    Enum.flat_map(
      date_services,
      &(edges_by_service |> Map.get(&1, %{}) |> Map.get(stop_id, []))
    )
  end

  @spec stop_id_by_code(stop_code()) :: {:ok, stop_id()} | :error
  def stop_id_by_code(code) do
    case Worker.get(:stop_id_by_code) |> Map.get(code) do
      nil -> :error
      id -> {:ok, id}
    end
  end

  @spec stop_name(stop_id()) :: String.t()
  def stop_name(id) do
    Worker.get(:stop_names) |> Map.get(id)
  end
end

defmodule TranslinkDb.Query.Data.Worker do
  @moduledoc "Load data from DB to `:persistent_term` on start, then exit."

  use GenServer
  @registry TranslinkDb.Registry

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via(name))
  end

  def get(name) do
    case :persistent_term.get(name, :loading) do
      :loading -> await_load(name)
      loaded -> loaded
    end
  end

  defp await_load(name) do
    # There is no `handle_call`,
    # all this does is wait for `handle_continue(:load, name)` to finish
    GenServer.call(via(name), nil, :infinity)
  catch
    # When loading finishes, process will exit, so this branch will hit
    :exit, {:normal, _} ->
      :persistent_term.get(name)

    :exit, {:noproc, _} ->
      throw("Did you forget to call TranslinkDb.Query.Data.load()?")
  end

  defp via(name) do
    {:via, Registry, {@registry, {__MODULE__, name}}}
  end

  @impl true
  def init(name) do
    {:ok, name, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, name) do
    :persistent_term.put(name, apply(Calculator, name, []))
    {:stop, :normal, name}
  end
end

defmodule TranslinkDb.Query.Data.Calculator do
  @moduledoc "Util module for all loading calculations"

  def walk_edges() do
    # TODO:
    # - Many pairs have a->b distance but not b->a, should be safe to derive.
    # - For others, estimate based on geo-coordinates
    from(
      transfer in StopTransfer,
      select: {
        transfer.from_stop_id,
        fragment("array_agg(?)", transfer.to_stop_id),
        fragment("array_agg(?)", transfer.seconds)
      },
      group_by: transfer.from_stop_id
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
      select: {service.date, fragment("array_agg(?)", service.id)},
      group_by: service.date
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

  @ride_edge_buckets 256

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
      select: {min(row.trip_id), max(row.trip_id)},
      group_by: row.bucket
    )
    |> Repo.all()
    |> Task.async_stream(
      &ride_edges/1,
      max_concurrency: @ride_edge_buckets,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce(%{}, fn {:ok, bucket}, acc ->
      Map.merge(acc, bucket, fn _service_id, a, b ->
        Map.merge(a, b, fn _from_stop_id, chunk1, chunk2 -> chunk1 ++ chunk2 end)
      end)
    end)
    |> Map.new(fn {service_id, stops} ->
      {service_id,
       Map.new(stops, fn {from_stop_id, chunks} ->
         {from_stop_id, Enum.concat(chunks)}
       end)}
    end)
  end

  defp ride_edges({from_trip_id, to_trip_id}) do
    # TODO: handle pickup & dropoff flags
    # For now, all stops allow pickup and dropoff

    # Note: No need to specifically handle trip_transfer,
    # they are naturally discovered when searching routes.

    query =
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
      row in subquery(query),
      where: not is_nil(row.to_stop_id) and not is_nil(row.to_arrival)
    )
    |> Repo.all()
    |> Enum.group_by(& &1.service_id)
    |> Map.new(fn {service_id, rows} ->
      {service_id,
       rows
       |> Enum.group_by(& &1.from_stop_id)
       |> Map.new(fn {from_stop_id, rows} ->
         {from_stop_id, [rows |> Enum.map(&Map.delete(&1, :service_id))]}
       end)}
    end)
  end
end
