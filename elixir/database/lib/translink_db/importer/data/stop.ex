defmodule TranslinkDb.Importer.Stop do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.{Station, Stop}

  @spec import_data(map()) :: :ok
  def import_data(feed) do
    IO.puts("\nImporting stops and stations")

    {stations, stops} =
      feed
      |> Map.fetch!("stops.txt")
      |> CSV.stream("stops.txt")
      |> Enum.reduce({[], []}, fn row, {stations, stops} ->
        case parse_row(row) do
          {:ok, {:station, attrs}} ->
            {[attrs | stations], stops}

          {:ok, {:stop, attrs}} ->
            {stations, [attrs | stops]}

          :ok ->
            {stations, stops}

          {:error, message} ->
            IO.puts("Discarding row: #{message}")
            {stations, stops}
        end
      end)

    Batch.insert_in_batches(Station, Enum.reverse(stations))
    Batch.insert_in_batches(Stop, Enum.reverse(stops))
  end

  defp parse_row(row) do
    with {:ok, location_type} <- Parser.integer(row, "location_type") do
      case location_type do
        0 ->
          with {:ok, attrs} <- stop_attrs(row), do: {:ok, {:stop, attrs}}

        1 ->
          with {:ok, attrs} <- station_attrs(row), do: {:ok, {:station, attrs}}

        2 ->
          # Station entrances, we don't need those
          :ok

        other ->
          {:error, "#{row.file}:#{row.line}: unknown location_type #{inspect(other)}"}
      end
    end
  end

  defp station_attrs(row) do
    with {:ok, id} <- Parser.integer(row, "stop_id"),
         {:ok, name} <- Parser.string(row, "stop_name"),
         {:ok, latitude} <- Parser.float(row, "stop_lat"),
         {:ok, longitude} <- Parser.float(row, "stop_lon") do
      {:ok, %{id: id, name: name, latitude: latitude, longitude: longitude}}
    end
  end

  defp stop_attrs(row) do
    with {:ok, id} <- Parser.integer(row, "stop_id"),
         {:ok, code} <- Parser.optional_integer(row, "stop_code"),
         {:ok, name} <- Parser.string(row, "stop_name"),
         {:ok, latitude} <- Parser.float(row, "stop_lat"),
         {:ok, longitude} <- Parser.float(row, "stop_lon"),
         {:ok, station_id} <- Parser.optional_integer(row, "parent_station") do
      {:ok,
       %{
         id: id,
         code: code,
         name: name,
         latitude: latitude,
         longitude: longitude,
         station_id: station_id
       }}
    end
  end
end
