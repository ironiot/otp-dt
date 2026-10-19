defmodule TranslinkDb.Importer.Trip do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.Trip

  @spec import_data(map()) :: :ok
  def import_data(feed) do
    IO.puts("\nImporting trips")

    trips =
      feed
      |> Map.fetch!("trips.txt")
      |> CSV.stream("trips.txt")
      |> Enum.reduce([], fn row, trips ->
        case trip_attrs(row) do
          {:ok, attrs} ->
            [attrs | trips]

          {:error, message} ->
            IO.puts("Discarding row: #{message}")
            trips
        end
      end)
      |> Enum.reverse()

    Batch.insert_in_batches(Trip, trips)
  end

  defp trip_attrs(row) do
    with {:ok, id} <- Parser.integer(row, "trip_id"),
         {:ok, headsign} <- Parser.string(row, "trip_headsign"),
         {:ok, route_id} <- Parser.integer(row, "route_id"),
         {:ok, service_id} <- Parser.integer(row, "service_id") do
      {:ok,
       %{
         id: id,
         headsign: headsign,
         route_id: route_id,
         service_id: service_id
       }}
    end
  end
end
