defmodule TranslinkFetcher do
  use GenServer

  @fetch_period_ms 1000 * 120

  @type request :: {:trip_updates, String.t()} | {:stop_updates, String.t()}
  @doc """
  A call that has not been replied due to data not being available yet.,
  `[waiter()]` is this GenServer's state.
  """
  @type waiter :: {pid(), request()}

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def get_trip_updates(trip_id) do
    GenServer.call({:global, __MODULE__}, {:trip_updates, trip_id}, @fetch_period_ms)
  end

  def get_stop_updates(stop_id) do
    GenServer.call({:global, __MODULE__}, {:stop_updates, stop_id}, @fetch_period_ms)
  end

  @impl true
  def init(_) do
    # Act as queues, potentially holding multiple updates.
    # `get_trip_updates` / `get_stop_updates` will block until data is available,
    # then clear the queue.
    :ets.new(:trip_updates, [:bag, :named_table, :private])
    :ets.new(:stop_updates, [:bag, :named_table, :private])
    {:ok, [], {:continue, :fetch}}
  end

  @impl true
  def handle_continue(:fetch, waiters) do
    fetch_cycle(waiters)
  end

  @impl true
  def handle_info(:fetch, waiters) do
    fetch_cycle(waiters)
  end

  @impl true
  def handle_call(request, from, waiters) do
    case take_data(request) do
      [] -> {:noreply, [{from, request} | waiters]}
      values -> {:reply, values, waiters}
    end
  end

  defp fetch_cycle(waiters) do
    TranslinkFetcher.Parser.run()
    Process.send_after(self(), :fetch, @fetch_period_ms)
    {:noreply, handle_waiters(waiters)}
  end

  # Take data from the ETS table for a given request.
  @spec take_data(request()) :: [any()]
  defp take_data({type, id}) do
    type |> :ets.take(id) |> Enum.map(&elem(&1, 1))
  end

  # Process the waiter list, fulfill requests whose data is available,
  # return the remaining waiters.
  @spec handle_waiters([waiter()]) :: [waiter()]
  defp handle_waiters(waiters) do
    Enum.filter(waiters, fn {from, request} ->
      case take_data(request) do
        [] ->
          true

        data ->
          GenServer.reply(from, data)
          false
      end
    end)
  end
end
