defmodule TranslinkDb.Importer do
  alias TranslinkDb.Importer.{Feed, Route, Service, Stop, StopTime, Transfer, Trip}
  alias TranslinkDb.Repo

  @spec run() :: :ok | {:error, term()}
  def run do
    with {:ok, feed} <- Feed.fetch() do
      case Repo.transaction(fn ->
             truncate_all()
             Stop.import_data(feed)
             Route.import_data(feed)
             Service.import_data(feed)
             Trip.import_data(feed)
             Transfer.import_data(feed)
             StopTime.import_data(feed)
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
      service,
      stop,
      station,
      route
    """)
  end
end
