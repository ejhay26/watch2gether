package api

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/scraper"
	"github.com/gofiber/fiber/v2"
)

type MediaHandler struct {
	scraper scraper.Scraper
}

func NewMediaHandler(s scraper.Scraper) *MediaHandler {
	return &MediaHandler{scraper: s}
}

func (h *MediaHandler) RegisterRoutes(router fiber.Router) {
	api := router.Group("/api/v1")

	api.Get("/health", h.Health)
	api.Get("/trending", h.GetTrending)
	api.Get("/recommendations", h.GetRecommendations)
	api.Get("/search", h.Search)
	api.Get("/details", h.GetDetails)
	api.Get("/episodes", h.GetEpisodes)
	api.Get("/servers", h.GetServers)
	api.Get("/sources", h.GetSources)
	api.Get("/sources/tracked", h.GetTrackedSources)
	api.Get("/subtitles/vtt", h.GetVTTSubtitles)
	api.Get("/subtitles/proxy", h.ProxySubtitles)
	api.Get("/subtitles/search", h.SearchSubtitles)
}

func (h *MediaHandler) Health(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"status":  "ok",
		"service": "watch2gether-backend",
		"version": "1.0.6",
	})
}

func (h *MediaHandler) GetTrending(c *fiber.Ctx) error {
	items, err := h.scraper.GetTrending()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"items": items,
	})
}

func (h *MediaHandler) GetRecommendations(c *fiber.Ctx) error {
	mediaID := c.Query("id")
	if mediaID == "" {
		items, err := h.scraper.GetTrending()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": err.Error(),
			})
		}
		return c.JSON(fiber.Map{
			"items": items,
		})
	}

	if mgr, ok := h.scraper.(*scraper.Manager); ok {
		items, err := mgr.GetRecommendations(mediaID)
		if err == nil && len(items) > 0 {
			return c.JSON(fiber.Map{
				"items": items,
			})
		}
	}

	items, err := h.scraper.GetTrending()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"items": items,
	})
}

func (h *MediaHandler) Search(c *fiber.Ctx) error {
	query := c.Query("q")
	if query == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Query parameter 'q' is required",
		})
	}

	items, err := h.scraper.Search(query)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"query": query,
		"items": items,
	})
}

func (h *MediaHandler) GetDetails(c *fiber.Ctx) error {
	id := c.Query("id")
	if id == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Query parameter 'id' is required",
		})
	}

	details, err := h.scraper.GetDetails(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(details)
}

func (h *MediaHandler) GetEpisodes(c *fiber.Ctx) error {
	id := c.Query("id")
	if id == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Query parameter 'id' is required",
		})
	}

	seasonStr := c.Query("season", "1")
	season, _ := strconv.Atoi(seasonStr)
	if season < 1 {
		season = 1
	}

	episodes, err := h.scraper.GetEpisodes(id, season)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"episodes": episodes,
	})
}

func (h *MediaHandler) GetServers(c *fiber.Ctx) error {
	episodeId := c.Query("episodeId")
	if episodeId == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Query parameter 'episodeId' is required",
		})
	}
	title := c.Query("title")

	var servers []scraper.Server
	var err error
	if mgr, ok := h.scraper.(*scraper.Manager); ok {
		servers, err = mgr.GetServersWithTitle(episodeId, title)
	} else {
		servers, err = h.scraper.GetServers(episodeId)
	}
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"servers": servers,
	})
}

func (h *MediaHandler) GetSources(c *fiber.Ctx) error {
	serverId := c.Query("serverId")
	if serverId == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Query parameter 'serverId' is required",
		})
	}
	title := c.Query("title")

	var stream *scraper.StreamResult
	var err error
	if mgr, ok := h.scraper.(*scraper.Manager); ok {
		stream, err = mgr.GetStreamWithTitle(serverId, title)
	} else {
		stream, err = h.scraper.GetStream(serverId)
	}
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(stream)
}

func (h *MediaHandler) GetVTTSubtitles(c *fiber.Ctx) error {
	lang := c.Query("lang", "en")
	title := c.Query("title", "Feature Presentation")

	c.Set("Content-Type", "text/vtt; charset=utf-8")
	c.Set("Access-Control-Allow-Origin", "*")

	vtt := fmt.Sprintf(`WEBVTT - %s [%s]

1
00:00:01.000 --> 00:00:06.000
[%s - Audio Stream Active]

2
00:00:06.500 --> 00:00:12.000
Subtitles synchronized with multi-source video playback.
`, title, strings.ToUpper(lang), title)

	return c.SendString(vtt)
}

func (h *MediaHandler) ProxySubtitles(c *fiber.Ctx) error {
	rawURL := c.Query("url")
	if rawURL == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Missing 'url' query parameter",
		})
	}

	client := &http.Client{Timeout: 15 * time.Second}
	req, err := http.NewRequest("GET", rawURL, nil)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "*/*")

	resp, err := client.Do(req)
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": err.Error()})
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{
			"error": fmt.Sprintf("Upstream server returned %d", resp.StatusCode),
		})
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	content := string(bodyBytes)
	c.Set("Content-Type", "text/vtt; charset=utf-8")
	c.Set("Access-Control-Allow-Origin", "*")

	// Convert SRT to WebVTT if needed
	if !strings.HasPrefix(strings.TrimSpace(content), "WEBVTT") {
		// Convert comma timestamps to dot timestamps e.g. 00:01:15,247 -> 00:01:15.247
		reSRTTimestamp := regexp.MustCompile(`(\d{2}:\d{2}:\d{2}),(\d{3})`)
		content = "WEBVTT\n\n" + reSRTTimestamp.ReplaceAllString(content, "${1}.${2}")
	}

	return c.SendString(content)
}

func (h *MediaHandler) SearchSubtitles(c *fiber.Ctx) error {
	query := c.Query("q")
	imdb := c.Query("imdb")
	lang := c.Query("lang")

	mgr, ok := h.scraper.(*scraper.Manager)
	if !ok || mgr.GetSubtitleEngine() == nil {
		return c.JSON(fiber.Map{
			"subtitles": []interface{}{},
		})
	}

	subs, err := mgr.GetSubtitleEngine().SearchSubtitles(c.Context(), query, imdb, lang)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{
		"subtitles": subs,
	})
}

func (h *MediaHandler) GetTrackedSources(c *fiber.Ctx) error {
	mgr, ok := h.scraper.(*scraper.Manager)
	if !ok {
		return c.JSON(fiber.Map{
			"total":   0,
			"sources": []interface{}{},
		})
	}
	tracked := mgr.GetVideoEngine().GetTrackedRegistry().GetAllTracked()
	return c.JSON(fiber.Map{
		"total":   len(tracked),
		"sources": tracked,
	})
}
