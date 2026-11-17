defmodule Mix.Tasks.Start do
  use Mix.Task

  @impl true
  def run(_) do
    if System.get_env("TRANSLINK_API_KEY") == nil do
      Mix.raise("TRANSLINK_API_KEY env var missing")
    end

    Mix.Task.run("app.start")
    Process.sleep(:infinity)
  end
end
