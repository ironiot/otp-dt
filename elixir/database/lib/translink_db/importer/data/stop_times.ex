defmodule TranslinkDb.Importer.StopTimes do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.StopTime

  @spec run(map()) :: :ok
  def run(feed) do
    IO.puts("\nImporting stop times")

    rows =
      feed
      |> Map.fetch!("stop_times.txt")
      |> CSV.stream("stop_times.txt")
      |> Stream.flat_map(fn row ->
        case stop_time_attrs(row) do
          {:ok, attrs} ->
            [attrs]

          {:error, message} ->
            IO.puts("Discarding row: #{message}")
            []
        end
      end)

    Batch.insert_in_batches(StopTime, rows)
  end

  defp stop_time_attrs(row) do
    with {:ok, trip_id} <- Parser.integer(row, "trip_id"),
         {:ok, stop_sequence} <- Parser.integer(row, "stop_sequence"),
         {:ok, stop_id} <- Parser.integer(row, "stop_id"),
         {:ok, arrival} <- Parser.time(row, "arrival_time"),
         {:ok, departure} <- Parser.time(row, "departure_time"),
         {:ok, pickup} <- Parser.stop_flag(row, "pickup_type"),
         {:ok, dropoff} <- Parser.stop_flag(row, "drop_off_type") do
      {:ok,
       %{
         trip_id: trip_id,
         stop_sequence: stop_sequence,
         stop_id: stop_id,
         arrival: arrival,
         departure: departure,
         pickup: pickup,
         dropoff: dropoff
       }}
    end
  end
end
