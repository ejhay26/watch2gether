package scraper

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDemoProviderDirect(t *testing.T) {
	demo := NewDemoProvider()

	// Test Trending
	trending, err := demo.GetTrending()
	if err != nil || len(trending) == 0 {
		t.Fatalf("Expected demo trending items, got %v, err: %v", trending, err)
	}

	// Test Search
	searchRes, err := demo.Search("sintel")
	if err != nil || len(searchRes) == 0 {
		t.Fatalf("Expected search results for sintel")
	}

	// Test Details
	details, err := demo.GetDetails("demo-sintel")
	if err != nil || details.Title == "" {
		t.Fatalf("Expected details for demo-sintel, err: %v", err)
	}

	// Test Episodes
	episodes, err := demo.GetEpisodes("demo-sintel", 1)
	if err != nil || len(episodes) == 0 {
		t.Fatalf("Expected episodes, err: %v", err)
	}

	// Test Servers
	servers, err := demo.GetServers(episodes[0].ID)
	if err != nil || len(servers) == 0 {
		t.Fatalf("Expected servers, err: %v", err)
	}

	// Test Stream
	stream, err := demo.GetStream(servers[0].ID)
	if err != nil || len(stream.Sources) == 0 {
		t.Fatalf("Expected stream sources, err: %v", err)
	}
	if !stream.Sources[0].IsM3U8 {
		t.Errorf("Expected M3U8 stream format")
	}
}

func TestManagerWithMockServer(t *testing.T) {
	// Setup mock FlixHQ server
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		switch r.URL.Path {
		case "/home":
			fmt.Fprintln(w, `
				<div id="trending-movies">
					<div class="flw-item">
						<div class="film-poster">
							<a href="/movie-mock-123"><img data-src="https://img.mock/1.jpg"/></a>
						</div>
						<div class="film-detail">
							<h3 class="film-name"><a href="/movie-mock-123">Mock Movie 2026</a></h3>
						</div>
					</div>
				</div>
			`)
		case "/search/mock":
			fmt.Fprintln(w, `
				<div class="flw-item">
					<div class="film-poster">
						<a href="/movie-mock-123"><img data-src="https://img.mock/1.jpg"/></a>
					</div>
					<div class="film-detail">
						<h3 class="film-name"><a href="/movie-mock-123">Mock Movie 2026</a></h3>
						<div class="fd-infor"><span class="fdi-item">2026</span></div>
					</div>
				</div>
			`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer mockServer.Close()

	scraper := NewFlixHQScraper(mockServer.URL)
	demo := NewDemoProvider()
	mgr := NewManagerWithProviders(scraper, demo)

	// Test trending with mock
	trending, err := mgr.GetTrending()
	if err != nil {
		t.Fatalf("GetTrending failed: %v", err)
	}
	if len(trending) < 2 {
		t.Fatalf("Expected combined trending results, got %d", len(trending))
	}

	// Test search with mock
	searchRes, err := mgr.Search("mock")
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(searchRes) == 0 {
		t.Fatalf("Expected mock search result")
	}
	found := false
	for _, it := range searchRes {
		if it.ID == "movie-mock-123" {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("Expected movie-mock-123 in search results")
	}
}
