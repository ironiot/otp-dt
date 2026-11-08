defmodule Mix.Tasks.Dev do
  use Mix.Task

  @impl true
  def run(_) do
    Mix.Task.run("app.start")
    TranslinkDb.Data.load()
  end
end
