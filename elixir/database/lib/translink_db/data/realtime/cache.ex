alias TranslinkDb.Data.Type
alias TranslinkDb.Util.Time
alias TranslinkDb.Data.Realtime.DB

defmodule TranslinkDb.Data.Realtime.Cache do
  @moduledoc """
  An LRU cache for realtime data.

  Data is stored by date.
  When a date is queried for the first time,
  load the entire data for that date.
  When the cache exceeds maximum size,
  remove the least recently used date from the cache.
  """

  use GenServer
  @max_size 24

  @type table :: :trips_cancelled? | :stops_status
  @type next_eviction :: %{
          table() => %{Date.t() => boolean()}
        }

  # `Type.stops_status` are the effective updates, to be used for querying.
  # `incoming_stops_status` are coming from the realtime fetcher,
  # that's why some fields are nil.
  # `incoming_stops_status` becomes `Type.stops_status` by applying default values.
  @type incoming_stops_status :: %{
          Type.trip_id() => %{
            Type.stop_sequence() => %{
              skipped: boolean() | nil,
              arrival_delay: Type.seconds() | nil,
              departure_delay: Type.seconds() | nil
            }
          }
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec get(:trips_cancelled?, Date.t()) :: Type.trips_cancelled?()
  @spec get(:stops_status, Date.t()) :: Type.stops_status()
  def get(table, date) do
    case :ets.lookup(table, date) do
      [{^date, updates}] ->
        GenServer.cast(__MODULE__, {table, date})
        updates

      [] ->
        GenServer.call(__MODULE__, {table, date}, :infinity)
    end
  end

  @spec update(:trips_cancelled?, Date.t(), Type.trips_cancelled?()) :: :ok
  @spec update(:stops_status, Date.t(), incoming_stops_status()) :: :ok
  def update(table, date, updates) do
    GenServer.cast(__MODULE__, {table, date, updates})
  end

  @impl true
  def init(_) do
    :trips_cancelled? |> :ets.new([:named_table, read_concurrency: true])
    :stops_status |> :ets.new([:named_table, read_concurrency: true])
    :recently_used |> :ets.new([:named_table, :private])
    {:ok, nil, {:continue, :load_today}}
  end

  @impl true
  def handle_continue(:load_today, _) do
    today = Time.today()
    load(today)
    {:noreply, %{trips_cancelled: today, stops_status: today}}
  end

  @impl true
  @spec handle_cast({table(), Date.t()}, next_eviction()) ::
          {:noreply, next_eviction()}
  def handle_cast({table, date}, next_eviction) do
    mark_used(table, date)
    {:noreply, next_eviction |> rotate(table, date)}
  end

  @impl true
  @spec handle_cast(
          {:trips_cancelled?, Date.t(), Type.trips_cancelled?()},
          next_eviction()
        ) :: {:reply, :ok, next_eviction()}
  def handle_cast({:trips_cancelled?, date, trips_cancelled}, next_eviction) do
    DB.update_trips(date, trips_cancelled)
    mark_used(:trips_cancelled?, date)
    {:noreply, next_eviction}
  end

  @impl true
  @spec handle_cast(
          {:stops_status, Date.t(), incoming_stops_status()},
          next_eviction()
        ) :: {:noreply, next_eviction()}
  def handle_cast({:stops_status, date, updates}, next_eviction) do
    merge_nullable = fn _k, old_v, new_v ->
      case new_v do
        nil -> old_v
        _ -> new_v
      end
    end

    normalized_updates =
      map_values(updates, fn trip_updates ->
        map_values(trip_updates, fn update ->
          Map.merge(
            %{skipped: false, arrival_delay: 0, departure_delay: 0},
            update,
            merge_nullable
          )
        end)
      end)

    stops_status =
      ets_update(:stops_status, date, normalized_updates, fn current ->
        Map.merge(current, updates, fn _trip_id, old_trip_updates, new_trip_updates ->
          Map.merge(old_trip_updates, new_trip_updates, fn _stop_seq, old_update, new_update ->
            Map.merge(old_update, new_update, merge_nullable)
          end)
        end)
      end)

    DB.update_stops(date, stops_status)
    mark_used(:stops_status, date)
    {:noreply, next_eviction}
  end

  @impl true
  @spec handle_call(
          {:trips_cancelled?, Date.t()},
          GenServer.from(),
          next_eviction()
        ) :: {:reply, Type.trips_cancelled?(), next_eviction()}
  @spec handle_call(
          {:stops_status, Date.t()},
          GenServer.from(),
          next_eviction()
        ) :: {:reply, Type.stops_status(), next_eviction()}
  def handle_call({table, date}, _from, next_eviction) do
    load(date)

    # These tables have the same size so can check either one
    if :ets.info(:trips_cancelled?, :size) > @max_size do
      Enum.each(
        [:trip_cancelled, :stops_status],
        fn table ->
          next_eviction
          |> Map.get(table)
          |> find_lru(table)
          |> tap(&:ets.delete(table, &1))
          |> tap(&mark_unused(table, &1))
        end
      )
    end

    {:reply, get(table, date), next_eviction |> rotate(table, date)}
  end

  @spec load(Date.t()) :: any()
  defp load(date) do
    updates = DB.get_updates(date)

    trips_cancelled =
      updates
      |> Map.new(fn {trip_id, update} -> {trip_id, update.cancelled} end)

    stops_status =
      updates
      |> Map.new(fn {trip_id, update} -> {trip_id, update.stops} end)

    :trips_cancelled?
    |> tap(&:ets.insert(&1, {date, trips_cancelled}))
    |> tap(&mark_used(&1, date))

    :stops_status
    |> tap(&:ets.insert(&1, {date, stops_status}))
    |> tap(&mark_used(&1, date))
  end

  @spec mark_used(table(), Date.t()) :: any()
  defp mark_used(table, date) do
    is_used_today = %{date => true}
    ets_update(:recently_used, table, is_used_today, &Map.merge(&1, is_used_today))
  end

  @spec mark_unused(table(), Date.t()) :: any()
  defp mark_unused(table, date) do
    with [{^table, new_value}] <- :ets.lookup(:recently_used, table) do
      new_value = new_value |> Map.delete(date)
      :recently_used |> :ets.insert({table, new_value})
    end
  end

  @spec rotate(Date.t(), table()) :: Date.t()
  defp rotate(date, table) do
    with :"$end_of_table" <- :ets.next(table, date) do
      :ets.first(table)
    end
  end

  @spec rotate(next_eviction(), table(), Date.t()) :: next_eviction()
  defp rotate(next_eviction, table, date) do
    next_eviction |> Map.put(table, rotate(date, table))
  end

  @spec find_lru(Date.t(), table()) :: Date.t()
  defp find_lru(date, table) do
    with [{^table, recently_used}] <- :ets.lookup(:recently_used, table),
         true <- Map.get(recently_used, date) do
      date |> rotate(table) |> find_lru(table)
    else
      _ -> date
    end
  end

  # similar signature to `Map.update/4`
  defp ets_update(table, key, default, fun) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        new_value = fun.(value)
        :ets.insert(table, {key, new_value})
        new_value

      [] ->
        :ets.insert(table, {key, default})
        default
    end
  end

  defp map_values(map, fun) do
    map
    |> Enum.map(fn {k, v} -> {k, fun.(v)} end)
    |> Map.new()
  end
end
