package api

import (
	"strconv"

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
	api.Get("/search", h.Search)
	api.Get("/details", h.GetDetails)
	api.Get("/episodes", h.GetEpisodes)
	api.Get("/servers", h.GetServers)
	api.Get("/sources", h.GetSources)
}

func (h *MediaHandler) Health(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"status":  "ok",
		"service": "watch2gether-backend",
		"version": "1.0.0",
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

	servers, err := h.scraper.GetServers(episodeId)
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

	stream, err := h.scraper.GetStream(serverId)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}
	return c.JSON(stream)
}
