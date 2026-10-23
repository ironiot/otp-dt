## Structure of Real Time Data
feed
 ├── header (timestamp, gtfs_realtime_version)
 └── entity (List of FeedEntity items)
      ├── [0] FeedEntity
      │    ├── id: "14092831"
      │    └── trip_update
      │         ├── trip
      │         │    ├── trip_id: "14092831"
      │         │    ├── route_id: "6636"      (e.g., Route 99 B-Line)
      │         │    └── start_date: "20261022"
      │         ├── vehicle
      │         │    └── id: "18042"           (The physical bus number)
      │         └── stop_time_update (List of upcoming stops for this trip)
      │              ├── [0] StopTimeUpdate
      │              │    ├── stop_sequence: 1
      │              │    ├── stop_id: "50913"
      │              │    └── arrival: { delay: 120, time: 1792729400 }
      │              └── [1] StopTimeUpdate ...
      ├── [1] FeedEntity ...
      └── [2] FeedEntity ...



## Usage
```
Run 'mix dept.get'
iex -S mix
```
```
TranslinkFetcher.fetch_trips("API KEY")
```
