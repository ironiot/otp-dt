defmodule Mix.Tasks.Start do
  use Mix.Task

  @impl true
  def run(_) do
    Mix.Task.run("app.start")
    Process.sleep(:infinity)
  end
end
