defmodule TranslinkDb.Data.Realtime.Updater.Stop do
  @moduledoc """
  TODO:
  	- Spawn one for each stop in the system.
   	- In a loop:
     + Call TranslinkFetcher.get_stop_updates(stop_id)
     + (This pretends each stop is generating its own data.)
     + Write to DB
     + Notify central state to update.
  """

  use GenServer
  @registry TranslinkDb.Registry

  def start_link(stop_id) do
    GenServer.start_link(__MODULE__, stop_id, name: via(stop_id))
  end

  defp via(stop_id) do
    {:via, Registry, {@registry, stop_id}}
  end

  @impl true
  def init(stop_id) do
    {:ok, stop_id}
  end
end
