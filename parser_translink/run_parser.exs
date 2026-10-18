files = Translink.StaticParser.fetch_and_extract()

stops = Translink.StaticParser.parse_stops(files["stops.txt"])
routes = Translink.StaticParser.parse_routes(files["routes.txt"])
trips = Translink.StaticParser.parse_trips(files["trips.txt"])

IO.puts("Loaded #{map_size(stops)} stops, #{map_size(routes)} routes, and #{map_size(trips)} trips.")

# bottom does work, just not needed for now

# target_bus = "099"

# Display a route and its directions
# case Enum.find(routes, fn {_route_id, info} -> info.short_name == target_bus end) do
#   {route_id, route_info} ->
#     IO.puts("\n=== Route #{route_info.short_name}: #{route_info.long_name} ===")
#     IO.puts("Internal Route ID: #{route_id}")

#     headsigns =
#       trips
#       |> Enum.filter(fn {_trip_id, trip} -> trip.route_id == route_id end)
#       |> Enum.map(fn {_trip_id, trip} -> trip.headsign end)
#       |> Enum.uniq()

#     IO.puts("Destinations / Headsigns:")
#     Enum.each(headsigns, fn sign -> IO.puts("  -> #{sign}") end)

#   nil ->
#     IO.puts("Route #{target_bus} not found! (Tip: Try 3 digits like '099' or '014')")
# end