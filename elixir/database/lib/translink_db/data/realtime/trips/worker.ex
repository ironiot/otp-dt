alias TranslinkDb.Data.Type
alias TranslinkDb.Data.Realtime.Cache

defmodule TranslinkDb.Data.Realtime.TripWorker do
  use GenServer
  require Logger

  @registry TranslinkDb.Registry
  @data_src {:global, TranslinkFetcher}
  @fetch_period_ms 1000 * 120

  def start_link(trip_id) do
    GenServer.start_link(__MODULE__, trip_id, name: via(trip_id))
  end

  defp via(trip_id) do
    {:via, Registry, {@registry, trip_id}}
  end

  @impl true
  def init(trip_id) do
    {:ok, trip_id, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, trip_id) do
    fetch_cycle(trip_id)
  end

  @impl true
  def handle_info(:fetch, trip_id) do
    fetch_cycle(trip_id)
  end

  # TODO: For a digital twin, we should simulate being able to
  # - cancel a trip
  # - skip a stop
  # - delay a stop
  # - query trip status

  @impl true
  def handle_call(:cancel, _from, _trip_id) do
    # TODO
  end

  @impl true
  @spec handle_call(
          {:skip, Type.stop_sequence()},
          GenServer.from(),
          Type.trip_id()
        ) :: {:reply, :ok, Type.trip_id()}
  def handle_call({:skip, _stop_sequence}, _from, _trip_id) do
    # TODO
  end

  @impl true
  @spec handle_call(
          {:delay, Type.stop_sequence(), Type.seconds()},
          GenServer.from(),
          Type.trip_id()
        ) :: {:reply, :ok, Type.trip_id()}
  def handle_call({:delay, _stop_sequence, _seconds}, _from, _trip_id) do
    # TODO
  end

  @impl true
  @spec handle_call(
          :status,
          GenServer.from(),
          Type.trip_id()
        ) :: {:reply, Type.trip_status(), Type.trip_id()}
  def handle_call(:status, _from, _trip_id) do
    # TODO
    # Caller should catch no process error
    # and interpret that as trip is not active.
  end

  defp fetch_cycle(trip_id) do
    fetch(trip_id)

    if !Application.get_env(:translink_db, :interactive, true) do
      Logger.info("Fetched updates for trip #{trip_id}")
    end

    Process.send_after(self(), :fetch, @fetch_period_ms)
    {:noreply, trip_id}
  end

  defp fetch(trip_id) do
    trip_id
    |> get_updates()
    |> Enum.sort_by(& &1.update_time)
    |> Enum.group_by(& &1.date)
    |> Enum.each(fn {date, updates} ->
      Cache.update(
        :trips_cancelled,
        date,
        Enum.reduce(updates, %{}, fn update, acc ->
          case update.cancelled do
            nil -> acc
            cancelled -> acc |> Map.put(update.trip_id, cancelled)
          end
        end)
      )

      Cache.update(
        :stops_status,
        date,
        Enum.reduce(updates, %{}, fn update, acc ->
          trip_updates =
            update.stops
            |> Enum.filter(fn stop ->
              stop.skipped != nil ||
                stop.arrival_delay != nil ||
                stop.departure_delay != nil
            end)
            |> Enum.map(fn stop ->
              {stop.stop_sequence,
               %{
                 skipped: stop.skipped,
                 arrival_delay: stop.arrival_delay,
                 departure_delay: stop.departure_delay
               }}
            end)
            |> Map.new()

          Map.update(
            acc,
            update.trip_id,
            trip_updates,
            &Map.merge(&1, trip_updates, fn _stop_seq, old_update, new_update ->
              Map.merge(old_update, new_update, fn _k, old_v, new_v ->
                case new_v do
                  nil -> old_v
                  _ -> new_v
                end
              end)
            end)
          )
        end)
      )
    end)
  end

  @spec get_updates(Type.trip_id()) ::
          [
            %{
              update_time: integer(),
              trip_id: Type.trip_id(),
              date: Date.t(),
              cancelled: boolean() | nil,
              stops: [
                %{
                  stop_sequence: Type.stop_sequence(),
                  skipped: boolean() | nil,
                  arrival_delay: Type.seconds() | nil,
                  departure_delay: Type.seconds() | nil
                }
              ]
            }
          ]
  defp get_updates(trip_id) do
    try do
      GenServer.call(@data_src, trip_id, @fetch_period_ms)
    catch
      :exit, {:timeout, _} -> []
    end
  end
end
