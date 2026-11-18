alias TranslinkDb.Data.Realtime.{Cache, TripSupervisor, TripManager}
alias TranslinkDb.Util.Time
alias TranslinkDb.Data.Type

defmodule TranslinkDb.Data.Realtime do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children = [Cache, TripSupervisor, TripManager]
    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec trip_cancelled?(Type.trip_id(), Date.t()) :: Type.trip_cancelled?()
  def trip_cancelled?(trip_id, date \\ Time.today()) do
    default = false

    :trips_cancelled?
    |> Cache.get(date)
    |> Map.get(trip_id, default)
  end

  @spec stop_status(Type.trip_id(), Type.stop_sequence(), Date.t()) :: Type.stop_status()
  def stop_status(trip_id, stop_sequence, date \\ Time.today()) do
    default = %{
      skipped: false,
      arrival_delay: 0,
      departure_delay: 0
    }

    :stops_status
    |> Cache.get(date)
    |> Map.get(trip_id, %{})
    |> Map.get(stop_sequence, default)
  end
end
