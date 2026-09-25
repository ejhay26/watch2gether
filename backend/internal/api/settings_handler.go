package api

import (
	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/gofiber/fiber/v2"
)

type SettingsHandler struct {
	db        *database.DB
	jwtSecret string
}

func NewSettingsHandler(db *database.DB, jwtSecret string) *SettingsHandler {
	return &SettingsHandler{
		db:        db,
		jwtSecret: jwtSecret,
	}
}

func (h *SettingsHandler) RegisterRoutes(router fiber.Router) {
	settings := router.Group("/api/v1/settings", AuthRequired(h.jwtSecret))

	settings.Get("/", h.GetSettings)
	settings.Post("/", h.SaveSettings)
}

type UpdateSettingsRequest struct {
	LiquidGlass      *bool   `json:"liquid_glass"`
	AutoSyncParty    *bool   `json:"auto_sync_party"`
	HardwareAccel    *bool   `json:"hardware_accel"`
	SubtitlesEnabled *bool   `json:"subtitles_enabled"`
	DefaultQuality   *string `json:"default_quality"`
}

func (h *SettingsHandler) GetSettings(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)

	s, err := h.db.GetSettings(c.UserContext(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"settings": s,
	})
}

func (h *SettingsHandler) SaveSettings(c *fiber.Ctx) error {
	userID, _ := c.Locals("userID").(string)

	var req UpdateSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request payload",
		})
	}

	current, err := h.db.GetSettings(c.UserContext(), userID)
	if err != nil {
		current = &database.UserSettings{
			UserID:           userID,
			LiquidGlass:      true,
			AutoSyncParty:    true,
			HardwareAccel:    true,
			SubtitlesEnabled: true,
			DefaultQuality:   "Auto",
		}
	}

	if req.LiquidGlass != nil {
		current.LiquidGlass = *req.LiquidGlass
	}
	if req.AutoSyncParty != nil {
		current.AutoSyncParty = *req.AutoSyncParty
	}
	if req.HardwareAccel != nil {
		current.HardwareAccel = *req.HardwareAccel
	}
	if req.SubtitlesEnabled != nil {
		current.SubtitlesEnabled = *req.SubtitlesEnabled
	}
	if req.DefaultQuality != nil && *req.DefaultQuality != "" {
		current.DefaultQuality = *req.DefaultQuality
	}

	if err := h.db.SaveSettings(c.UserContext(), current); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status":   "saved",
		"settings": current,
	})
}
