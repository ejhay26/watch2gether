package scraper

import (
	"testing"
)

func TestSearchParamedic(t *testing.T) {
	tmdb := NewTMDBScraper("")
	results, err := tmdb.Search("The Paramedic")
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	for i, r := range results {
		t.Logf("Result %d: %s (%s, ID=%s)", i, r.Title, r.Year, r.ID)
	}

	details, err := tmdb.GetDetails("tmdb-movie-701175")
	if err != nil {
		t.Fatalf("Failed to get details: %v", err)
	}
	t.Logf("The Paramedic (2020) Details: Title=%s, AgeRating=%s, Duration=%s, Year=%s", details.Title, details.AgeRating, details.Duration, details.Year)
}

func TestTMDBScraperDirect(t *testing.T) {
	tmdb := NewTMDBScraper("")
	// Test Trending
	trending, err := tmdb.GetTrending()
	if err != nil || len(trending) == 0 {
		t.Fatalf("Expected TMDB trending items, got %d items, err: %v", len(trending), err)
	}
	t.Logf("Fetched %d trending items from TMDB. First item: %s (%s)", len(trending), trending[0].Title, trending[0].Year)

	// Test Search
	searchRes, err := tmdb.Search("avatar")
	if err != nil || len(searchRes) == 0 {
		t.Fatalf("Expected search results for avatar, got %d items, err: %v", len(searchRes), err)
	}
	t.Logf("Search for 'avatar' returned %d items. First item: %s (%s)", len(searchRes), searchRes[0].Title, searchRes[0].ID)

	// Test Details
	details, err := tmdb.GetDetails("tmdb-movie-19995")
	if err != nil || details.Title == "" {
		t.Fatalf("Expected details for tmdb-movie-19995, err: %v", err)
	}
	t.Logf("Details for Avatar: %s, %s, %v, AgeRating=%s", details.Title, details.Rating, details.Genres, details.AgeRating)

	// Test The Paramedic Details
	paramedicDetails, err := tmdb.GetDetails("tmdb-movie-623199")
	if err == nil {
		t.Logf("The Paramedic AgeRating: %s", paramedicDetails.AgeRating)
	}

	// Test Episodes
	episodes, err := tmdb.GetEpisodes(searchRes[0].ID, 1)
	if err != nil || len(episodes) == 0 {
		t.Fatalf("Expected episodes, err: %v", err)
	}

	// Test Servers
	servers, err := tmdb.GetServers(episodes[0].ID)
	if err != nil || len(servers) == 0 {
		t.Fatalf("Expected servers, err: %v", err)
	}

	// Test Stream
	stream, err := tmdb.GetStream(servers[0].ID)
	if err != nil || len(stream.Sources) == 0 {
		t.Fatalf("Expected stream sources, err: %v", err)
	}
	if !stream.Sources[0].IsM3U8 {
		t.Errorf("Expected M3U8 format")
	}
}
