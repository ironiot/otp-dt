defmodule TranslinkDb.Importer.Transfer do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.{StopTransfer, TripTransfer}

  @spec import_data(map()) :: :ok
  def import_data(feed) do
    IO.puts("\nImporting transfers")

    {stop_transfers, trip_transfers} =
      feed
      |> Map.fetch!("transfers.txt")
      |> CSV.stream("transfers.txt")
      |> Enum.reduce({[], []}, fn row, {stop_transfers, trip_transfers} ->
        case parse_row(row) do
          {:ok, {:stop_transfer, attrs}} ->
            {[attrs | stop_transfers], trip_transfers}

          {:ok, {:trip_transfer, attrs}} ->
            {stop_transfers, [attrs | trip_transfers]}

          {:error, message} ->
            IO.puts("Discarding row: #{message}")
            {stop_transfers, trip_transfers}
        end
      end)

    Batch.insert_in_batches(StopTransfer, Enum.reverse(stop_transfers))
    Batch.insert_in_batches(TripTransfer, Enum.reverse(trip_transfers))
  end

  defp parse_row(row) do
    with {:ok, transfer_type} <- Parser.integer(row, "transfer_type") do
      case transfer_type do
        type when type in [0, 2] ->
          with {:ok, attrs} <- stop_transfer_attrs(row) do
            {:ok, {:stop_transfer, attrs}}
          end

        4 ->
          with {:ok, attrs} <- trip_transfer_attrs(row) do
            {:ok, {:trip_transfer, attrs}}
          end

        other ->
          {:error, "#{row.file}:#{row.line}: unknown transfer_type #{inspect(other)}"}
      end
    end
  end

  defp stop_transfer_attrs(row) do
    with {:ok, from_stop_id} <- Parser.integer(row, "from_stop_id"),
         {:ok, to_stop_id} <- Parser.integer(row, "to_stop_id"),
         {:ok, seconds} <- Parser.integer(row, "min_transfer_time") do
      {:ok, %{from_stop_id: from_stop_id, to_stop_id: to_stop_id, seconds: seconds}}
    end
  end

  defp trip_transfer_attrs(row) do
    with {:ok, from_trip_id} <- Parser.integer(row, "from_trip_id"),
         {:ok, to_trip_id} <- Parser.integer(row, "to_trip_id"),
         {:ok, stop_id} <- Parser.integer(row, "from_stop_id") do
      {:ok, %{from_trip_id: from_trip_id, to_trip_id: to_trip_id, stop_id: stop_id}}
    end
  end
end
