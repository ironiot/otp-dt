defmodule TranslinkDb.Query.Server do
  use GenServer

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      nil,
      name: {:global, __MODULE__}
    )
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:route, src, des}, _from, _state) do
    {:reply, TranslinkDb.Query.BestRoute.find(src, des), nil}
  end

  @impl GenServer
  def handle_call({:route, src, des, time}, _from, _state) do
    {:reply, TranslinkDb.Query.BestRoute.find(src, des, time), nil}
  end

  @impl GenServer
  def handle_call({:upcoming_rides, stop_id, time}, _from, _state) do
    {
      :reply, 
      %{ stop_id: stop_id, time: time },
      nil
    }
  end

  @impl GenServer
  def handle_call({:upcoming_rides, stop_id}, _from, _state) do
    {
      :reply, 
      %{ stop_id: stop_id, time: nil },
      nil
    }
  end
end
