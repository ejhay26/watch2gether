package anime

import (
	"context"
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
	if len(servers) > 0 {
		t.Logf("Server 0: ID=%s, Name=%s", servers[0].ID, servers[0].Name)
		stream, err := ane.GetStream(ctx, servers[0].ID)
		if err != nil {
			t.Logf("GetStream failed: %v", err)
		} else {
			t.Logf("GetStream SUCCESS! Sources=%d, Subtitles=%d", len(stream.Sources), len(stream.Subtitles))
		}
	}
}
