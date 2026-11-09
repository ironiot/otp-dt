# Go collector

Polls TransLink's GTFS-realtime trip updates and writes the history to TimescaleDB.

## Setup

Needs PostgreSQL with the TimescaleDB extension.

```
psql "$DATABASE_URL" -f schema.sql
```

## Run

```
export TRANSLINK_API_KEY=...
export DATABASE_URL=postgres:///translink_db
go run ./cmd/collector
```

