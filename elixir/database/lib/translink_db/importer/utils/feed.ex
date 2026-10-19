defmodule TranslinkDb.Importer.Feed do
  @url "https://gtfs-static.translink.ca/gtfs/google_transit.zip"

  @required_files ~w(
    calendar.txt
    calendar_dates.txt
    routes.txt
    stops.txt
    stop_times.txt
    transfers.txt
    trips.txt
  )

  @type files :: %{required(String.t()) => binary()}
  @spec fetch() :: {:ok, files()} | {:error, term()}
  def fetch do
    IO.puts("Fetching #{@url}")

    with {:ok, archive} <- download(),
         {:ok, files} <- unzip(archive) do
      validate_required_files(files)
    end
  end

  defp download do
    case Req.get(@url, decode_body: false, receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, {:http_error, reason}}
    end
  end

  defp unzip(archive) do
    case :zip.unzip(archive, [:memory]) do
      {:ok, entries} ->
        files =
          Map.new(entries, fn {name, content} ->
            {name |> List.to_string() |> Path.basename(), content}
          end)

        {:ok, files}

      {:error, reason} ->
        {:error, {:unzip_error, reason}}
    end
  end

  defp validate_required_files(files) do
    missing = Enum.reject(@required_files, &Map.has_key?(files, &1))

    case missing do
      [] -> {:ok, files}
      missing -> {:error, {:missing_files, missing}}
    end
  end
end
