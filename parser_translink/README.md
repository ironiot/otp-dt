

## Output of Parser
make sure to run mix deps.get
### Routes with key route_id
```
%{
  "6636" => %{
    short_name: "099",
    long_name: "Commercial-Broadway / UBC (B-Line)"
  }
}
```

### Stops with key stop_id
```
%{
  "1842" => %{
    stop_code: "50913",
    name: "Commercial-Broadway Station Bay 5",
    lat: 49.262544,
    lon: -123.068842
  },
  "1845" => %{
    stop_code: "50916",
    name: "WB E Broadway @ Clark Dr",
    lat: 49.262271,
    lon: -123.077259
  }
}
```

### Trips with key trip_id
```
%{
  "14251022" => %{
    route_id: "6636",
    headsign: "99 UBC B-LINE",
    direction_id: "1"
  }
}
```

### Ordered Stops
```
[
  %{
    sequence: 1,
    stop_code: "50913",
    stop_name: "Commercial-Broadway Station Bay 5",
    arrival_time: "08:00:00"
  },
  %{
    sequence: 2,
    stop_code: "50916",
    stop_name: "WB E Broadway @ Clark Dr",
    arrival_time: "08:03:00"
  }
]
```

## Example
```
my_stop = stops["1842"]

IO.puts(my_stop.name)      # => "Commercial-Broadway Station Bay 5"
IO.puts(my_stop.stop_code) # => "50913"
IO.puts(my_stop.lat)       # => 49.262544
```