defmodule TranslinkDb.Importer do
  alias TranslinkDb.Importer.{Calendars, Feed, Routes, Stops, StopTimes, Transfers, Trips}
  alias TranslinkDb.Repo

  @spec run() :: :ok | {:error, term()}
  def run do
    with {:ok, feed} <- Feed.fetch() do
      case Repo.transaction(fn ->
             truncate_all()
             Stops.run(feed)
             Routes.run(feed)
             Calendars.run(feed)
             Trips.run(feed)
             Transfers.run(feed)
             StopTimes.run(feed)
           end) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp truncate_all do
    IO.puts("\nDeleting all existing data, if any")

    Repo.query!("""
    TRUNCATE TABLE
      trip_transfer,
      stop_transfer,
      stop_time,
      trip,
      service_date,
      service,
      stop,
      station,
      route
    """)
  end
end
