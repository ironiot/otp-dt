defmodule Api.Worker do
  use GenServer

  @server TranslinkDb.Query.Server

  def start_link(nil) do
	  GenServer.start_link(__MODULE__, name: __MODULE__)
  end

  def route(source, destination) do
	  GenServer.call(
      {:global, @server},
      {:route, source, destination}
    )
  end

  def route(source, destination, date) do
	  GenServer.call(
      {:global, @server},
      {:route, source, destination, date}
    )
  end

  def upcoming_rides(stop_id) do
    GenServer.call(
      {:global, @server},
      {:upcoming_rides, stop_id}
    )
  end

  def upcoming_rides(stop_id, time) do
    GenServer.call(
      {:global, @server},
      {:upcoming_rides, stop_id, time}
    )
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

end
