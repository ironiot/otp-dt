defmodule TranslinkFetcher.Parser do
  @moduledoc "Static module for fetching GTFS realtime data."

  require Logger

  @url "https://gtfsapi.translink.ca/v3/gtfsrealtime"
  @api_key System.get_env("TRANSLINK_API_KEY")

  @doc """
  Fetch realtime data once.
  Data is saved in ETS tables if successful, errors are logged.
  Caller is responsible for scheduling periodic calls
  and to not exceed rate limit.
  """
  def run() do
    with {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(@url, params: [apikey: @api_key]),
         {:ok, feed} <- Protox.decode(body, TransitRealtime.FeedMessage) do
      Enum.each(feed.entity, &apply_update(&1.trip_update, feed.header.timestamp))
      Logger.info("Fetch successful")
    else
      error -> Logger.error("Fetch failed: #{inspect(error)}")
    end
  end

  defp apply_update(trip_update, update_time) do
    with %{trip: trip, stop_time_update: stop_time_update} <- trip_update,
         {:ok, trip_id} <- parse_id(trip.trip_id),
         {:ok, trip_date} <- parse_date(trip.start_date) do
      :ets.insert(
        :trip_updates,
        {trip_id,
         %{
           update_time: update_time,
           trip_id: trip_id,
           date: trip_date,
           cancelled:
             case trip.schedule_relationship do
               nil -> nil
               :CANCELLED -> true
               _ -> false
             end
         }}
      )

      stop_time_update
      |> Enum.filter(&(&1.stop_id != nil && &1.stop_sequence != nil))
      |> Enum.each(
        &with {:ok, stop_id} <- parse_id(&1.stop_id) do
          :ets.insert(
            :stop_updates,
            {stop_id,
             %{
               update_time: update_time,
               trip_id: trip_id,
               date: trip_date,
               stop_sequence: &1.stop_sequence,
               skipped:
                 case &1.schedule_relationship do
                   nil -> nil
                   :NO_DATA -> nil
                   :SKIPPED -> true
                   _ -> false
                 end,
               arrival_delay:
                 with %{delay: delay} <- &1.arrival do
                   delay
                 end,
               departure_delay:
                 with %{delay: delay} <- &1.departure do
                   delay
                 end
             }}
          )
        end
      )
    end
  end

  @spec parse_id(String.t()) :: {:ok, integer()} | nil
  defp parse_id(id_str) do
    try do
      {:ok, String.to_integer(id_str)}
    rescue
      ArgumentError ->
        nil
    end
  end

  @spec parse_date(String.t()) :: {:ok, Date.t()} | {:error, any()}
  defp parse_date(date_str) do
    try do
      year = String.slice(date_str, 0, 4) |> String.to_integer()
      month = String.slice(date_str, 4, 2) |> String.to_integer()
      day = String.slice(date_str, 6, 2) |> String.to_integer()

      case Date.new(year, month, day) do
        {:ok, date} -> {:ok, date}
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end
end
