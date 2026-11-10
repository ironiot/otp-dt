alias TranslinkDb.Data.Static
alias TranslinkDb.Data.Realtime.TripSupervisor

defmodule TranslinkDb.Data.Realtime.TripManager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Static.trip_ids() |> Enum.map(&TripSupervisor.start_trip/1)
    {:ok, nil}
  end

  # TODO:
  # When TripWorker timeouts, send a message to TripManager and die.
  # TripManager determines based on the static data
  # whether that trip is still ongoing; if yes, restart the worker,
  # if no, schedule the worker to restart on the next day that trip is active.
  # This should save memory. There are 60k trips, but only 20k active each day.
  # But for now, all TripWorkers stay alive at all time.
  @impl true
  def handle_info({:timeout, _trip_id, _date}, state) do
    {:noreply, state}
  end
end
