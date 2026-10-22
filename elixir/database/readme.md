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
    {:stop, 56985}, # airport
    {:stop, 60358}, # UBC
    {:departure, DateTime.new!(~D[2026-10-10], ~T[14:00:00], "Canada/Pacific")}
)
# results
%{
  arrival: "2026-10-10 15:14:00",
  travel_time: "1h 2m 39s",
  route: [
    %{
      via: "412 Bridgeport Station",
      to: "Bridgeport Station @ Bay 1 Unloading Only",
      from: "Vancouver Airport @ South Terminal",
      departure: "2026-10-10 14:11:21",
      duration: "13m 39s"
    },
    %{
      via: "Walking",
      to: "Bridgeport Station @ Platform 1",
      from: "Bridgeport Station @ Bay 1 Unloading Only",
      departure: "2026-10-10 14:25:00",
      duration: "4m"
    },
    %{
      via: "Canada Line To Waterfront",
      to: "Oakridge-41st Avenue Station @ Platform 1",
      from: "Bridgeport Station @ Platform 1",
      departure: "2026-10-10 14:31:00",
      duration: "6m"
    },
    %{
      via: "Walking",
      to: "Oakridge-41st Ave Station @ Bay 5",
      from: "Oakridge-41st Avenue Station @ Platform 1",
      departure: "2026-10-10 14:37:00",
      duration: "4m"
    },
    %{
      via: "41 41st Avenue/To Crown St",
      to: "Westbound W 41 Ave @ East Blvd",
      from: "Oakridge-41st Ave Station @ Bay 5",
      departure: "2026-10-10 14:41:19",
      duration: "9m 50s"
    },
    %{
      via: "R4 41st Avenue/To UBC Exchange",
      to: "UBC Exchange @ Unloading Only",
      from: "Westbound W 41 Ave @ East Blvd",
      departure: "2026-10-10 14:53:02",
      duration: "20m 58s"
    }
  ]
}
```

## Actually running in prod

Not yet. You just have to manually test `TranslinkDb.Query.BestRoute` in iex.
But eventually this will be hooked into an API router.
