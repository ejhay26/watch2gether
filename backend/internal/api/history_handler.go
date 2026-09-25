package api

import (
	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/gofiber/fiber/v2"
)

type HistoryHandler struct {
	db        *database.DB
	jwtSecret string
}

func NewHistoryHandler(db *database.DB, jwtSecret string) *HistoryHandler {
	return &HistoryHandler{
		db:        db,
		jwtSecret: jwtSecret,
	}
}

func (h *HistoryHandler) RegisterRoutes(router fiber.Router) {
	history := router.Group("/api/v1/history", AuthRequired(h.jwtSecret))

	history.Post("/", h.SaveHistory)
	history.Get("/", h.GetHistory)
	history.Delete("/", h.DeleteHistory)
	history.Delete("/all", h.ClearAllHistory)
}

type SaveHistoryRequest struct {
	MediaID          string `json:"media_id"`
	Title            string `json:"title"`
	Poster           string `json:"poster"`
	EpisodeID        string `json:"episode_id"`
	TimestampSeconds int    `json:"timestamp_seconds"`
	DurationSeconds  int    `json:"duration_seconds"`
	IsWatched        *bool  `json:"is_watched,omitempty"`
}

func (h *HistoryHandler) SaveHistory(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)

	var req SaveHistoryRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request payload",
		})
	}

	if req.MediaID == "" || req.Title == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "media_id and title are required",
		})
	}

	// Auto-detect watched if >90% duration, or if explicitly passed
	isWatched := false
	if req.IsWatched != nil {
		isWatched = *req.IsWatched
	} else if req.DurationSeconds > 0 && req.TimestampSeconds >= int(float64(req.DurationSeconds)*0.90) {
		isWatched = true
	}

	item := &database.WatchHistory{
		UserID:           userID,
		MediaID:          req.MediaID,
		Title:            req.Title,
		Poster:           req.Poster,
		EpisodeID:        req.EpisodeID,
		TimestampSeconds: req.TimestampSeconds,
		DurationSeconds:  req.DurationSeconds,
		IsWatched:        isWatched,
	}

	if err := h.db.SaveHistory(c.UserContext(), item); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "saved",
		"item":   item,
	})
}

func (h *HistoryHandler) GetHistory(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)

	items, err := h.db.GetHistory(c.UserContext(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"history": items,
	})
}

func (h *HistoryHandler) DeleteHistory(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)
	mediaID := c.Query("media_id")
	episodeID := c.Query("episode_id")

	if mediaID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "media_id query parameter is required",
		})
	}

	if err := h.db.DeleteHistory(c.UserContext(), userID, mediaID, episodeID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "deleted",
	})
}

func (h *HistoryHandler) ClearAllHistory(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)

	if err := h.db.ClearAllHistory(c.UserContext(), userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "cleared",
	})
}
