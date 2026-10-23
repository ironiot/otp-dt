defmodule TranslinkFetcher do
  alias TransitRealtime.FeedMessage

  def fetch_trips(api_key) do
    url = "https://gtfsapi.translink.ca/v3/gtfsrealtime"

    case Req.get(url, params: [apikey: api_key]) do
      {:ok, %Req.Response{status: 200, body: raw_binary}} ->
        {:ok, feed} = Protox.decode(raw_binary, FeedMessage)

        IO.puts("\nSuccess! Total trip updates received: #{length(feed.entity)}\n")

        
        feed.entity
        # |> Enum.take(10) THIS LIMITS IT TO 10 JUST FOR EASY PRINTING USAGE
        |> Enum.each(fn entity ->
          trip = entity.trip_update.trip
          IO.puts("Entity ID: #{entity.id} | Route ID: #{trip.route_id} | Trip ID: #{trip.trip_id}")

          entity.trip_update.stop_time_update
          |> Enum.take(1)
          |> Enum.each(fn stop ->
            delay = stop.arrival && stop.arrival.delay
            IO.puts("  -> Stop #{stop.stop_id} (Seq #{stop.stop_sequence}): Delay #{delay || 0}s")
          end)

          IO.puts(String.duplicate("-", 50))
        end)

      {:ok, %Req.Response{status: status, body: body}} ->
        IO.puts("HTTP Error #{status}: #{inspect(body)}")

      {:error, exception} ->
        IO.puts("Request failed: #{Exception.message(exception)}")
    end
  end 
end