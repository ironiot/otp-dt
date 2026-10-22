alias TranslinkDb.Repo
alias TranslinkDb.Schemas.{Service, StopTime, StopTransfer}
alias TranslinkDb.Query.DataWorker
import Ecto.Query

defmodule TranslinkDb.Query.Data do
  use Supervisor

  @type stop_id :: integer()
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

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # these are fast, fine to run on init
    :persistent_term.put(:walk_edges, compute_walk_edges())
    :persistent_term.put(:service_ids, compute_service_ids())

    # load ride edges in parallel, return immediately while they run in background
    from(s in Service, select: s.id, distinct: true)
    |> Repo.all()
    |> Enum.map(&Supervisor.child_spec({DataWorker, &1}, id: &1))
    |> Supervisor.init(strategy: :one_for_one)
  end

  @spec walk_edges(stop_id()) :: [walk_edge()]
  def walk_edges(stop_id) do
    :persistent_term.get(:walk_edges) |> Map.get(stop_id, [])
  end

  @spec service_ids(Date.t()) :: [service_id()]
  def service_ids(date \\ Date.utc_today()) do
    :persistent_term.get(:service_ids) |> Map.get(date)
  end

  @spec ride_edges([service_id()], stop_id()) :: [ride_edge()]
  def ride_edges(service_ids, stop_id) do
    Enum.flat_map(service_ids, &(DataWorker.ride_edges(&1) |> Map.get(stop_id, [])))
  end

  defp compute_walk_edges() do
    # TODO:
    # - Many pairs have a->b distance but not b->a, should be safe to derive.
    # - For others, estimate based on geo-coordinates
    from(
      t in StopTransfer,
      select: {
        t.from_stop_id,
        fragment("array_agg(?)", t.to_stop_id),
        fragment("array_agg(?)", t.seconds)
      },
      group_by: t.from_stop_id
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

  defp compute_service_ids() do
    from(
      s in Service,
      select: {s.date, fragment("array_agg(? order by ?)", s.id, s.id)},
      group_by: s.date
    )
    |> Repo.all()
    |> Map.new()
  end
end

defmodule TranslinkDb.Query.DataWorker do
  use GenServer
  @registry TranslinkDb.Registry

  def start_link(service_id) do
    GenServer.start_link(__MODULE__, service_id, name: via(service_id))
  end

  def ride_edges(service_id) do
    case :persistent_term.get(key(service_id), :loading) do
      :loading ->
        GenServer.call(via(service_id), :ride_edges)

      loaded ->
        loaded
    end
  end

  defp via(service_id) do
    {:via, Registry, {@registry, key(service_id)}}
  end

  defp key(service_id), do: {__MODULE__, service_id}

  @impl true
  def init(service_id) do
    {:ok, service_id, {:continue, :preload}}
  end

  @impl true
  def handle_continue(:preload, service_id) do
    :persistent_term.put(key(service_id), compute_ride_edges(service_id))
    {:noreply, service_id}
  end

  @impl true
  def handle_call(:ride_edges, _from, service_id) do
    {:reply, :persistent_term.get(key(service_id)), service_id}
  end

  defp compute_ride_edges(service_id) do
    # TODO: handle pickup & dropoff flags
    # For now, all stops allow pickup and dropoff
    from(
      stop in StopTime,
      join: trip in assoc(stop, :trip),
      where: trip.service_id == ^service_id,
      windows: [trip: [partition_by: stop.trip_id, order_by: stop.stop_sequence]],
      select: %{
        trip_id: stop.trip_id,
        from_stop_id: stop.stop_id,
        to_stop_id: lead(stop.stop_id) |> over(:trip),
        from_departure: stop.departure,
        to_arrival: lead(stop.arrival) |> over(:trip)
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.from_stop_id)
    |> Map.new(fn {from_stop_id, rows} ->
      {from_stop_id, Enum.filter(rows, &(&1.to_stop_id != nil && &1.to_arrival != nil))}
    end)
  end
end
