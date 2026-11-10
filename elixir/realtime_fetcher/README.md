# Realtime fetcher

A script to call TransLink API every 2 minutes, fetch and parses the data,
and store it in memory.

## Usage

```sh
mix start
```

## API

```ex
GenServer.call({:global, TranslinkFetcher}, trip_id, timeout)
# Return type:
# [
#   %{
#     update_time: integer(),
#     trip_id: integer(),
#     date: Date.t(),
#     cancelled: boolean() | nil,
#     stops: [
#       %{
#         stop_sequence: integer(),
#         skipped: boolean() | nil,
#         arrival_delay: integer() | nil,
#         departure_delay: integer() | nil
#        }
#     ]
#   }
# ]
```

Returns an array because multiple fetches may have occurred
since the last call; all of them will be returned.
Caller is responsible for merging/deduping the updates.

This call may block for upto 2 minutes to wait for the next fetch;
caller should apply appropriate timeout or catch the exception.
