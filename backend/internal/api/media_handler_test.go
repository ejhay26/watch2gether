package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ejhay26/watch2gether/backend/internal/scraper"
	"github.com/gofiber/fiber/v2"
)

func TestMediaHandlerEndpoints(t *testing.T) {
	app := fiber.New()
	demo := scraper.NewDemoProvider()
	handler := NewMediaHandler(demo)
	handler.RegisterRoutes(app)

	// 1. Health check
	req := httptest.NewRequest("GET", "/api/v1/health", nil)
	resp, err := app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Health check failed, status: %d, err: %v", resp.StatusCode, err)
	}

	// 2. Trending
	req = httptest.NewRequest("GET", "/api/v1/trending", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Trending failed, status: %d", resp.StatusCode)
	}
	var trendRes struct {
		Items []scraper.MediaItem `json:"items"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&trendRes)
	if len(trendRes.Items) == 0 {
		t.Fatalf("Expected trending items")
	}

	// 3. Search
	req = httptest.NewRequest("GET", "/api/v1/search?q=sintel", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Search failed, status: %d", resp.StatusCode)
	}

	// 4. Details
	req = httptest.NewRequest("GET", "/api/v1/details?id=demo-sintel", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Details failed, status: %d", resp.StatusCode)
	}

	// 5. Episodes
	req = httptest.NewRequest("GET", "/api/v1/episodes?id=demo-sintel", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Episodes failed, status: %d", resp.StatusCode)
	}

	// 6. Servers
	req = httptest.NewRequest("GET", "/api/v1/servers?episodeId=demo-sintel-ep1", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Servers failed, status: %d", resp.StatusCode)
	}

	// 7. Sources
	req = httptest.NewRequest("GET", "/api/v1/sources?serverId=demo-sintel-ep1-srv-cdn1", nil)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Sources failed, status: %d", resp.StatusCode)
	}
	var srcRes scraper.StreamResult
	_ = json.NewDecoder(resp.Body).Decode(&srcRes)
	if len(srcRes.Sources) == 0 || !srcRes.Sources[0].IsM3U8 {
		t.Fatalf("Expected valid M3U8 source in stream result")
	}
}
