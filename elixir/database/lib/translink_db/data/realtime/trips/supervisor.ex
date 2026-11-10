alias TranslinkDb.Data.Realtime.TripWorker

defmodule TranslinkDb.Data.Realtime.TripSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_trip(id) do
    child = Supervisor.child_spec({TripWorker, id}, restart: :transient)
    DynamicSupervisor.start_child(__MODULE__, child)
  end
end
