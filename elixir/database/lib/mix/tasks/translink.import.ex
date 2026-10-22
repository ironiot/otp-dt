defmodule Mix.Tasks.Translink.Import do
  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.start")

    case TranslinkDb.Importer.run() do
      {:error, reason} ->
        Mix.raise("Import failed: #{inspect(reason)}")

      :ok ->
        :ok
    end
  end
end
