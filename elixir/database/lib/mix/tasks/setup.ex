defmodule Mix.Tasks.Setup do
  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("ecto.drop")
    Mix.Task.run("ecto.create")
    Mix.Task.run("ecto.migrate")
    Mix.Task.run("translink.import")
  end
end
