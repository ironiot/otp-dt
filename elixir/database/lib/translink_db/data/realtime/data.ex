alias TranslinkDb.Data.Realtime.{Cache, TripSupervisor, TripManager}

defmodule TranslinkDb.Data.Realtime do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children = [Cache, TripSupervisor, TripManager]
    Supervisor.init(children, strategy: :one_for_one)
  end

  # TODO
  # Wrap Cache functions to expose prettier API for querying
end
