defmodule Mix.Tasks.Start do
  use Mix.Task

  @impl true
  def run(_) do
    Application.put_env(:translink_db, :interactive, false)
    Mix.Task.run("app.start")
    Process.sleep(:infinity)
  end
end
