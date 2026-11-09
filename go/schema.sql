-- Schema for the ironiot digital shadow. Requires TimescaleDB.
-- Apply once:  psql "$DATABASE_URL" -f schema.sql

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Predicted delays per trip and stop. The collector writes a row only when a
-- prediction changes, so this is a history of predictions, not one row per poll.
CREATE TABLE IF NOT EXISTS stop_delays (
    time            timestamptz NOT NULL,   -- trip update (or feed) timestamp
    trip_id         text        NOT NULL,
    route_id        text,
    stop_id         text        NOT NULL,
    stop_sequence   int,
    arrival_delay   int,                    -- seconds; NULL if not predicted
    departure_delay int                     -- seconds; NULL if not predicted
);
SELECT create_hypertable('stop_delays', 'time',
    chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS stop_delays_trip_stop_time
    ON stop_delays (trip_id, stop_id, time DESC);

-- Compress chunks older than 7 days.
ALTER TABLE stop_delays SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'route_id');
SELECT add_compression_policy('stop_delays', INTERVAL '7 days', if_not_exists => TRUE);

-- Hourly average predicted delay per route. Because stop_delays holds
-- prediction changes, this averages recorded predictions, not final arrivals.
CREATE MATERIALIZED VIEW IF NOT EXISTS route_delay_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
       route_id,
       avg(arrival_delay) AS avg_predicted_delay,
       count(*)           AS n
FROM stop_delays
GROUP BY bucket, route_id
WITH NO DATA;
SELECT add_continuous_aggregate_policy('route_delay_hourly',
    start_offset      => INTERVAL '3 hours',
    end_offset        => INTERVAL '1 hour',
    schedule_interval => INTERVAL '30 minutes',
    if_not_exists     => TRUE);
