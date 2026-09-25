package anime

import (
	"context"
	"strings"
	"testing"
)

func TestAnimeSearchAndStream(t *testing.T) {
	ane := NewAnimeEngine()
	ctx := context.Background()

	items, err := ane.Search(ctx, "Frieren")
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	t.Logf("Found %d items for Frieren", len(items))
	if len(items) == 0 {
		return
	}
	t.Logf("First item: ID=%s, Title=%s", items[0].ID, items[0].Title)

	eps, err := ane.GetEpisodes(ctx, items[0].ID)
	if err != nil {
		t.Fatalf("GetEpisodes failed: %v", err)
	}
	t.Logf("Found %d episodes", len(eps))
	if len(eps) == 0 {
		return
	}

	servers, err := ane.GetServers(ctx, eps[0].ID)
	if err != nil {
		t.Fatalf("GetServers failed: %v", err)
	}
	t.Logf("Found %d servers", len(servers))
	for _, s := range servers {
		t.Logf("Testing server: ID=%s, Name=%s", s.ID, s.Name)
		stream, err := ane.GetStream(ctx, s.ID)
		if err != nil {
			t.Errorf("GetStream failed for %s: %v", s.Name, err)
		} else {
			t.Logf("GetStream SUCCESS for %s! Quality=%s, URL=%s, Subs=%d", s.Name, stream.Sources[0].Quality, stream.Sources[0].URL[:35], len(stream.Subtitles))
		}
	}
}

func TestSeriesIDToServers(t *testing.T) {
	ane := NewAnimeEngine()
	ctx := context.Background()

	// Pass series ID directly instead of episode ID
	servers, err := ane.GetServers(ctx, "anime-frieren-beyond-journeys-end-481")
	if err != nil {
		t.Fatalf("GetServers failed for series ID: %v", err)
	}
	if len(servers) == 0 {
		t.Fatalf("Expected servers for series ID, got 0")
	}
	t.Logf("Got %d servers for series ID: %s", len(servers), servers[0].Name)
	if !strings.Contains(servers[0].ID, "9227") {
		t.Fatalf("Expected episode 9227 (Frieren Ep 1), got: %s", servers[0].ID)
	}
}
