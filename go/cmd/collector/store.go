package main

import (
	"context"
	"time"

	"github.com/MobilityData/gtfs-realtime-bindings/golang/gtfs"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// entityTime returns an entity's own timestamp
func entityTime(ts *uint64, feed *gtfs.FeedMessage) time.Time {
	if ts != nil {
		return time.Unix(int64(*ts), 0)
	}
	return time.Unix(int64(feed.GetHeader().GetTimestamp()), 0)
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// delay is the last prediction written for one stop visit of a trip
type delay struct {
	arr, dep       int32
	hasArr, hasDep bool
}

func delayOf(stu *gtfs.TripUpdate_StopTimeUpdate) delay {
	a, d := stu.GetArrival(), stu.GetDeparture()
	return delay{
		arr: a.GetDelay(), hasArr: a != nil && a.Delay != nil,
		dep: d.GetDelay(), hasDep: d != nil && d.Delay != nil,
	}
}

func optInt(v int32, ok bool) *int32 {
	if !ok {
		return nil
	}
	return &v
}

// stopKey identifies one stop visit of a trip. Some TransLink trips visit the
// same stop twice (see elixir/database/priv/repo/migrations/1_init.exs), so the
// stop sequence is part of the key
type stopKey struct {
	trip, stop string
	seq        uint32
}

// writes the stop predictions that changed since last and returns the predictions in this feed
func writeDelays(ctx context.Context, db *pgxpool.Pool, feed *gtfs.FeedMessage, last map[stopKey]delay) (map[stopKey]delay, int64, error) {
	rows, seen := changedDelays(feed, last)
	n, err := db.CopyFrom(ctx, pgx.Identifier{"stop_delays"},
		[]string{"time", "trip_id", "route_id", "stop_id", "stop_sequence", "arrival_delay", "departure_delay"},
		pgx.CopyFromRows(rows))
	if err != nil {
		return last, 0, err
	}
	return seen, n, nil
}

// returns the stop_delays rows for predictions that differ from last
func changedDelays(feed *gtfs.FeedMessage, last map[stopKey]delay) (rows [][]any, seen map[stopKey]delay) {
	seen = make(map[stopKey]delay)
	for _, e := range feed.GetEntity() {
		tu := e.GetTripUpdate()
		trip := tu.GetTrip()
		if trip.GetTripId() == "" {
			continue
		}
		t := entityTime(tu.Timestamp, feed)
		for _, stu := range tu.GetStopTimeUpdate() {
			if stu.GetStopId() == "" {
				continue
			}
			d := delayOf(stu)
			key := stopKey{trip.GetTripId(), stu.GetStopId(), stu.GetStopSequence()}
			seen[key] = d
			if old, ok := last[key]; ok && old == d {
				continue
			}
			var seq *int32
			if stu.StopSequence != nil {
				s := int32(stu.GetStopSequence())
				seq = &s
			}
			rows = append(rows, []any{
				t, trip.GetTripId(), nullIfEmpty(trip.GetRouteId()), stu.GetStopId(), seq,
				optInt(d.arr, d.hasArr), optInt(d.dep, d.hasDep),
			})
		}
	}
	return rows, seen
}
