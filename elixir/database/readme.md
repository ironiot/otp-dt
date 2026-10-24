## Setup

```
mix setup
```

Database is hardcoded as `translink_db`, belonging to your regular user.

## Testing

```
iex -S mix dev
```

Example:

```ex
TranslinkDb.Query.BestRoute.find(
    56985, # airport
    60358, # UBC
    {:departure, DateTime.new!(~D[2026-10-10], ~T[14:00:00], "Canada/Pacific")}
)
```

This searches for the exact bus stop codes. You can also search by stop names,
it uses fuzzy string matching to find the stops.

```ex
TranslinkDb.Query.BestRoute.find("airport", "ubc") # default time is now
```

The result looks something like this

```ex
%{
  arrival: "2026-10-23 15:18:00",
  travel_time: "1h 1m 15s",
  itinerary: [
    %{
      via: "412 Bridgeport Station",
      to: "Bridgeport Station @ Bay 1 Unloading Only",
      from: "Vancouver Airport @ South Terminal",
      duration: "15m 15s",
      departure: "2026-10-23 14:16:45"
    },
    %{
      via: "Walking",
      to: "Bridgeport Station @ Platform 1",
      from: "Bridgeport Station @ Bay 1 Unloading Only",
      duration: "4m",
      departure: "2026-10-23 14:32:00"
    },
    "Wait 1m",
    %{
      via: "Canada Line To Waterfront",
      to: "Langara-49th Avenue Station @ Platform 1",
      from: "Bridgeport Station @ Platform 1",
      duration: "5m",
      departure: "2026-10-23 14:37:00"
    },
    %{
      via: "Walking",
      to: "Langara-49th Station @ Bay 2",
      from: "Langara-49th Avenue Station @ Platform 1",
      duration: "5m",
      departure: "2026-10-23 14:42:00"
    },
    "Wait 2m",
    %{
      via: "49 49TH Avenue/To UBC Exchange",
      to: "UBC Exchange @ Unloading Only",
      from: "Langara-49th Station @ Bay 2",
      duration: "29m",
      departure: "2026-10-23 14:49:00"
    }
  ]
}
```

## Actually running in prod

Not yet. You just have to manually test `TranslinkDb.Query.BestRoute` in iex.
But eventually this will be hooked into an API router.
