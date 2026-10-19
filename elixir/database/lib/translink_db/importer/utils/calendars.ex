defmodule TranslinkDb.Importer.Calendars do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.{Service, ServiceDate}

  @weekdays ~w(monday tuesday wednesday thursday friday saturday sunday)

  @spec run(map()) :: :ok
  def run(feed) do
    calendar_rows =
      feed
      |> Map.fetch!("calendar.txt")
      |> CSV.stream("calendar.txt")
      |> Enum.flat_map(&parse_calendar_row/1)

    services =
      calendar_rows
      |> Enum.map(fn {service_id, _start_date, _end_date, _weekdays} -> %{id: service_id} end)
      |> Enum.sort_by(& &1.id)

    Batch.insert_in_batches(Service, services)

    service_dates =
      calendar_rows
      |> Enum.reduce(MapSet.new(), fn {service_id, start_date, end_date, weekdays},
                                      service_dates ->
        add_service_dates(service_id, start_date, end_date, weekdays, service_dates)
      end)
      |> apply_calendar_dates(Map.fetch!(feed, "calendar_dates.txt"))
      |> Enum.map(fn {service_id, date} -> %{service_id: service_id, date: date} end)
      |> Enum.sort_by(&{&1.service_id, &1.date})

    Batch.insert_in_batches(ServiceDate, service_dates)
  end

  defp parse_calendar_row(row) do
    with {:ok, service_id} <- Parser.integer(row, "service_id"),
         {:ok, start_date} <- Parser.date(row, "start_date"),
         {:ok, end_date} <- Parser.date(row, "end_date"),
         {:ok, weekdays} <- parse_weekdays(row) do
      [{service_id, start_date, end_date, weekdays}]
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

  defp add_service_dates(service_id, start_date, end_date, weekdays, service_dates) do
    Enum.reduce(Date.range(start_date, end_date), service_dates, fn date, service_dates ->
      if Map.fetch!(weekdays, weekday_field(date)) do
        MapSet.put(service_dates, {service_id, date})
      else
        service_dates
      end
    end)
  end

  defp apply_calendar_dates(service_dates, content) do
    content
    |> CSV.stream("calendar_dates.txt")
    |> Enum.reduce(service_dates, fn row, service_dates ->
      with {:ok, service_id} <- Parser.integer(row, "service_id"),
           {:ok, date} <- Parser.date(row, "date"),
           {:ok, exception_type} <- Parser.integer(row, "exception_type") do
        case exception_type do
          1 ->
            MapSet.put(service_dates, {service_id, date})

          2 ->
            MapSet.delete(service_dates, {service_id, date})

          other ->
            IO.puts(
              "Discarding row: #{row.file}:#{row.line}: invalid exception_type #{inspect(other)}"
            )

            service_dates
        end
      else
        {:error, message} ->
          IO.puts("Discarding row: #{message}")
          service_dates
      end
    end)
  end

  defp weekday_field(date) do
    Enum.at(@weekdays, Date.day_of_week(date) - 1)
  end
end
