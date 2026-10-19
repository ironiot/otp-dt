defmodule Mix.Tasks.Translink.Import do
  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.start")

    case TranslinkDb.Importer.run() do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.raise("Import failed: #{format_reason(reason)}")
    end
  end

  defp format_reason({:missing_files, files}) do
    "missing required files: #{Enum.join(files, ", ")}"
  end

  defp format_reason({:http_status, status}) do
    "feed download returned HTTP #{status}"
  end

  defp format_reason({:http_error, reason}) do
    "feed download failed: #{inspect(reason)}"
  end

  defp format_reason({:unzip_error, reason}) do
    "feed unzip failed: #{inspect(reason)}"
  end

  defp format_reason({:invalid_data, message}), do: message
  defp format_reason({:database_error, message}), do: message
end
