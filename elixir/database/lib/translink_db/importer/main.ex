defmodule TranslinkDb.Importer do
  alias TranslinkDb.Importer.{Feed, Service, Stop, StopTime, Transfer, Trip}
  alias TranslinkDb.Repo

  @spec run() :: :ok | {:error, term()}
  def run() do
    with {:ok, feed} <- Feed.fetch(),
         {:ok, _} <- Repo.transaction(fn -> run(feed) end) do
      :ok
    end
  end

  defp run(feed) do
    truncate_all()
    Stop.import_data(feed)
    Service.import_data(feed)
    Trip.import_data(feed)
    Transfer.import_data(feed)
    StopTime.import_data(feed)
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
      station
    """)
  end
end
