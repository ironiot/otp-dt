package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MobilityData/gtfs-realtime-bindings/golang/gtfs"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/protobuf/proto"
)

const (
	tripUpdatesURL  = "https://gtfsapi.translink.ca/v3/gtfsrealtime?apikey="
	requestsPerPoll = 1
)

var errBudgetSpent = errors.New("request budget for the last 24h is spent, skipping")

// fetch downloads one raw payload
func fetch(ctx context.Context, client *http.Client, feedURL string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, feedURL, nil)
	if err != nil {
		return nil, errors.New("bad feed URL")
	}
	resp, err := client.Do(req)
	if err != nil {
		var ue *url.Error
		if errors.As(err, &ue) {
			err = ue.Err
		}
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %s", resp.Status)
	}
	return io.ReadAll(resp.Body)
}

type poller struct {
	client *http.Client
	db     *pgxpool.Pool
	key    string
	budget *budget

	tripStamp  uint64
	lastDelays map[stopKey]delay
}

func (p *poller) getFeed(ctx context.Context, baseURL string) (*gtfs.FeedMessage, error) {
	if !p.budget.take(time.Now()) {
		return nil, errBudgetSpent
	}
	body, err := fetch(ctx, p.client, baseURL+p.key)
	if err != nil {
		return nil, err
	}
	feed := &gtfs.FeedMessage{}
	if err := proto.Unmarshal(body, feed); err != nil {
		return nil, err
	}
	return feed, nil
}

func (p *poller) poll(ctx context.Context) {
	trips, err := p.getFeed(ctx, tripUpdatesURL)
	if err != nil {
		log.Print("trip updates: ", err)
	} else if ts := trips.GetHeader().GetTimestamp(); ts != 0 && ts == p.tripStamp {
		log.Print("trip updates: feed unchanged")
	} else if seen, n, err := writeDelays(ctx, p.db, trips, p.lastDelays); err != nil {
		log.Print("trip updates: write: ", err)
	} else {
		p.tripStamp, p.lastDelays = ts, seen
		log.Printf("trip updates: %d trips, %d changed predictions", len(trips.GetEntity()), n)
	}
}

func main() {
	interval := flag.Duration("interval", 6*time.Minute,
		fmt.Sprintf("how often to poll the feed; each poll sends %d API request", requestsPerPoll))
	maxRequests := flag.Int("max-requests", 250,
		"most API requests to send in any 24 hours; TransLink allows 1000 per key per day, "+
			"and the Elixir realtime fetcher uses about 720 of them with the same key")
	flag.Parse()

	if *interval <= 0 || *maxRequests <= 0 {
		log.Fatal("-interval and -max-requests must be positive")
	}
	if perDay := requestsPerPoll * int(24*time.Hour / *interval); perDay > *maxRequests {
		log.Printf("warning: -interval %v needs %d requests a day but -max-requests is %d; "+
			"polls will be skipped once the budget is spent", *interval, perDay, *maxRequests)
	}

	key := os.Getenv("TRANSLINK_API_KEY")
	if key == "" {
		log.Fatal("TRANSLINK_API_KEY is not set")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal("database: ", err)
	}
	defer db.Close()
	if err := db.Ping(ctx); err != nil {
		log.Fatal("database: ", err)
	}

	p := &poller{
		client: &http.Client{Timeout: 15 * time.Second},
		db:     db,
		key:    key,
		budget: &budget{limit: *maxRequests},
	}

	ticker := time.NewTicker(*interval)
	defer ticker.Stop()
	for {
		p.poll(ctx)
		select {
		case <-ctx.Done():
			log.Print("shutting down")
			return
		case <-ticker.C:
		}
	}
}
