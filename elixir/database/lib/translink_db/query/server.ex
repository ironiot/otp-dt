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
    TranslinkDb.Data.load()
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
end
