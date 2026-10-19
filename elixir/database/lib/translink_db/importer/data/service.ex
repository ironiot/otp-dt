defmodule TranslinkDb.Importer.Service do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.Service

  @weekdays ~w(monday tuesday wednesday thursday friday saturday sunday)

  @spec import_data(map()) :: :ok
  def import_data(feed) do
    IO.puts("\nImporting services")

    calendar_rows =
      feed
      |> Map.fetch!("calendar.txt")
      |> CSV.stream("calendar.txt")
      |> Enum.flat_map(&parse_calendar_row/1)

    services =
      calendar_rows
      |> Enum.reduce(MapSet.new(), fn {id, start_date, end_date, weekdays}, services ->
        add_services(id, start_date, end_date, weekdays, services)
      end)
      |> apply_calendar_dates(Map.fetch!(feed, "calendar_dates.txt"))
      |> Enum.map(fn {id, date} -> %{id: id, date: date} end)

    Batch.insert_in_batches(Service, services)
  end

  defp parse_calendar_row(row) do
    with {:ok, id} <- Parser.integer(row, "service_id"),
         {:ok, start_date} <- Parser.date(row, "start_date"),
         {:ok, end_date} <- Parser.date(row, "end_date"),
         {:ok, weekdays} <- parse_weekdays(row) do
      [{id, start_date, end_date, weekdays}]
    else
      {:error, message} ->
        IO.puts("Discarding row: #{message}")
        []
    end
  end

  defp parse_weekdays(row) do
    Enum.reduce_while(@weekdays, {:ok, %{}}, fn field, {:ok, weekdays} ->
      case Parser.string(row, field) do
        {:ok, value} -> {:cont, {:ok, Map.put(weekdays, field, value == "1")}}
        {:error, _message} = error -> {:halt, error}
      end
    end)
  end

  defp add_services(id, start_date, end_date, weekdays, services) do
    Enum.reduce(Date.range(start_date, end_date), services, fn date, services ->
      if Map.fetch!(weekdays, weekday_field(date)) do
        MapSet.put(services, {id, date})
      else
        services
      end
    end)
  end

  defp apply_calendar_dates(services, content) do
    content
    |> CSV.stream("calendar_dates.txt")
    |> Enum.reduce(services, fn row, services ->
      with {:ok, id} <- Parser.integer(row, "service_id"),
           {:ok, date} <- Parser.date(row, "date"),
           {:ok, exception_type} <- Parser.integer(row, "exception_type") do
        case exception_type do
          1 ->
            MapSet.put(services, {id, date})

          2 ->
            MapSet.delete(services, {id, date})

          other ->
            IO.puts(
              "Discarding row: #{row.file}:#{row.line}: invalid exception_type #{inspect(other)}"
            )

            services
        end
      else
        {:error, message} ->
          IO.puts("Discarding row: #{message}")
          services
      end
    end)
  end

  defp weekday_field(date) do
    Enum.at(@weekdays, Date.day_of_week(date) - 1)
  end
end
