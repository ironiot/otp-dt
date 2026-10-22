defmodule Api.Worker do
  use GenServer

  @registry Api.Registry

  defp via(name) do
    {:via, Registry, {@registry, {__MODULE__, name}}}
  end


  # region CLIENT
  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via(name))
  end

  def get_route() do
    GenServer.call()
  end
  # endregion
  
  # region SERVER
  @impl GenServer
  def init(_) do
    {:ok, nil}
  end
  # endregion

end
