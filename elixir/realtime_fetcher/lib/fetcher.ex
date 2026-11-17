defmodule TranslinkFetcher do
  use GenServer

  @fetch_period_ms 1000 * 120

  @doc """
  A call that has not been replied due to data not being available yet.
  `[waiter()]` is this GenServer's state.
  """
  @type waiter :: {pid(), trip_id :: integer()}

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  @impl true
  def init(_) do
    # Act as a queue, potentially holding multiple updates for each trip.
    # `GenServer.call({:global, TranslinkFetcher}, trip_id)` will block
    # until the queue is not empty, then return everything in the queue and clear it.
    :updates |> :ets.new([:bag, :named_table, :private])
    {:ok, [], {:continue, :fetch}}
  end

  @impl true
  def handle_continue(:fetch, waiters) do
    fetch(waiters)
  end

  @impl true
  def handle_info(:fetch, waiters) do
    fetch(waiters)
  end

  @impl true
  def handle_call(trip_id, caller, waiters) do
    case take_data(trip_id) do
      [] -> {:noreply, [{caller, trip_id} | waiters]}
      values -> {:reply, values, waiters}
    end
  end

  defp fetch(waiters) do
    TranslinkFetcher.Parser.run()
    Process.send_after(self(), :fetch, @fetch_period_ms)
    {:noreply, handle_waiters(waiters)}
  end

  # Returns and remove a list of updates for a trip in the table.
  defp take_data(trip_id) do
    :updates |> :ets.take(trip_id) |> Enum.map(&elem(&1, 1))
  end

  # Process the waiter list, fulfill requests whose data is available,
  # return the remaining waiters.
  @spec handle_waiters([waiter()]) :: [waiter()]
  defp handle_waiters(waiters) do
    Enum.filter(waiters, fn {caller, trip_id} ->
      case take_data(trip_id) do
        [] ->
          true

        data ->
          GenServer.reply(caller, data)
          false
      end
    end)
  end
end
