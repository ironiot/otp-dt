defmodule Mix.Tasks.Dev do
  use Mix.Task

  @impl true
  def run(_) do
    Mix.Task.run("app.start")
    TranslinkDb.Query.Data.load()
  end
end
