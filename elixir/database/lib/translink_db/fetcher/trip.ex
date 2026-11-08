defmodule TranslinkDb.Fetcher.Trip do
  @moduledoc """
  TODO:
  	- Spawn one for each trip in the system.
   	- In a loop:
     + Call TranslinkFetcher.get_trip_updates()
     + (This pretents each trip is generating its own data.)
     + Write to DB
     + Motify TranslinkDb.Data to update its state
  """

  use GenServer
  @registry TranslinkDb.Registry

  def start_link(trip_id) do
    GenServer.start_link(__MODULE__, trip_id, name: via(trip_id))
  end

  defp via(trip_id) do
    {:via, Registry, {@registry, trip_id}}
  end

  @impl true
  def init(trip_id) do
    {:ok, trip_id}
  end
end
