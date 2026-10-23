alias TranslinkDb.Query.Data.Loader

defmodule TranslinkDb.Query.Data.Worker do
  @moduledoc "Load data from DB to `:persistent_term` on start, then exit."

  use GenServer
  @registry TranslinkDb.Registry

  @doc "`name` must be an exact function name of `TranslinkDb.Query.Data.Loader`"
  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via(name))
  end

  def get(name) do
    case :persistent_term.get(name, :loading) do
      :loading -> await_load(name)
      loaded -> loaded
    end
  end

  defp await_load(name) do
    # There is no `handle_call`,
    # all this does is wait for `handle_continue(:load, name)` to finish
    GenServer.call(via(name), nil, :infinity)
  catch
    # When loading finishes, process will exit, so this branch will hit
    :exit, {:normal, _} ->
      :persistent_term.get(name)

    :exit, {:noproc, _} ->
      throw("Did you forget to call TranslinkDb.Query.Data.load()?")
  end

  defp via(name) do
    {:via, Registry, {@registry, {__MODULE__, name}}}
  end

  @impl true
  def init(name) do
    {:ok, name, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, name) do
    :persistent_term.put(name, apply(Loader, name, []))
    {:stop, :normal, name}
  end
end
