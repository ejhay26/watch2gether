package video

import (
	"context"
	"testing"
)

func TestArchiveProviderFilms(t *testing.T) {
	p := NewArchiveProvider()
	films := p.GetAllFilms()

	if len(films) < 15 {
		t.Fatalf("Expected at least 15 verified films, got %d", len(films))
	}

	// Test specific known films
	testCases := []struct {
		id    string
		title string
	}{
		{"10331", "Night of the Living Dead"},
		{"4808", "Charade"},
		{"3085", "His Girl Friday"},
		{"961", "The General"},
		{"16075", "Carnival of Souls"},
		{"522", "Plan 9 from Outer Space"},
		{"653", "Nosferatu"},
		{"11337", "The Phantom of the Opera"},
		{"274", "The Cabinet of Dr. Caligari"},
		{"644", "Battleship Potemkin"},
		{"21614", "The Stranger"},
		{"18641", "Gulliver's Travels"},
		{"11341", "The Great Train Robbery"},
		{"10378", "Big Buck Bunny"},
		{"45745", "Sintel"},
		{"113333", "Tears of Steel"},
	}

	for _, tc := range testCases {
		film, found := p.Match(tc.id, tc.title)
		if !found {
			t.Errorf("Film %s (%s) not found in archive registry", tc.title, tc.id)
			continue
		}
		if len(film.Sources) == 0 {
			t.Errorf("Film %s has no sources registered", tc.title)
		}
		if film.Sources[0].URL == "" {
			t.Errorf("Film %s has empty primary stream URL", tc.title)
		}
	}
}

func TestVideoEngineDynamicServersAndStream(t *testing.T) {
	ve := NewVideoEngine(nil)

	// 1. Verify dynamic servers for an archive film
	servers, err := ve.GetServers("tmdb-movie-10331-ep1", "Night of the Living Dead")
	if err != nil {
		t.Fatalf("Failed to get servers for Night of the Living Dead: %v", err)
	}
	if len(servers) < 2 {
		t.Fatalf("Expected multiple dynamic servers, got %d", len(servers))
	}
	if servers[0].Name == "" {
		t.Errorf("Server name should not be empty")
	}

	// 2. Verify stream resolution
	stream, err := ve.GetStream(context.Background(), servers[0].ID, "Night of the Living Dead")
	if err != nil {
		t.Fatalf("Failed to get stream: %v", err)
	}
	if len(stream.Sources) == 0 {
		t.Fatalf("Expected sources in stream result, got 0")
	}
	if stream.Sources[0].URL == "" {
		t.Errorf("Stream URL must not be empty")
	}
	// Verify that Night of the Living Dead does NOT return Tears of Steel URL!
	if stream.Sources[0].URL == "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8" {
		t.Errorf("Night of the Living Dead incorrectly fell back to Tears of Steel!")
	}
}
