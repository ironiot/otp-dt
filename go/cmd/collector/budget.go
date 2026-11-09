package main

import "time"

type budget struct {
	limit int
	sent  []time.Time
}

// take reports whether a request may be sent at now
func (b *budget) take(now time.Time) bool {
	cutoff := now.Add(-24 * time.Hour)
	i := 0
	for i < len(b.sent) && !b.sent[i].After(cutoff) {
		i++
	}
	b.sent = b.sent[i:]
	if len(b.sent) >= b.limit {
		return false
	}
	b.sent = append(b.sent, now)
	return true
}
