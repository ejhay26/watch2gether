package room

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
	"github.com/google/uuid"
)

type RoomHandler struct {
	hub *Hub
}

func NewRoomHandler(hub *Hub) *RoomHandler {
	return &RoomHandler{hub: hub}
}

type fiberWSConn struct {
	*websocket.Conn
}

func (f *fiberWSConn) WriteJSON(v interface{}) error {
	return f.Conn.WriteJSON(v)
}

func (f *fiberWSConn) ReadJSON(v interface{}) error {
	return f.Conn.ReadJSON(v)
}

func (f *fiberWSConn) Close() error {
	return f.Conn.Close()
}

type CreateRoomRequest struct {
	MediaID   string `json:"media_id"`
	Title     string `json:"title"`
	StreamURL string `json:"stream_url"`
	EpisodeID string            `json:"episode_id"`
	Headers   map[string]string `json:"headers,omitempty"`
}

func (h *RoomHandler) RegisterRoutes(app fiber.Router) {
	api := app.Group("/api/v1/rooms")

	api.Post("/", func(c *fiber.Ctx) error {
		var req CreateRoomRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid request body",
			})
		}

		if req.Title == "" {
			req.Title = "Watch Together Room"
		}

		room := h.hub.CreateRoom("", req.MediaID, req.Title, req.StreamURL, req.EpisodeID, req.Headers)
		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"room_id":    room.ID,
			"title":      room.Title,
			"media_id":   room.MediaID,
			"stream_url": room.StreamURL,
			"headers":    room.Headers,
		})
	})

	api.Get("/:id", func(c *fiber.Ctx) error {
		roomID := c.Params("id")
		room, err := h.hub.GetRoom(roomID)
		if err != nil {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
				"error": "Room not found",
			})
		}

		room.mu.RLock()
		state := room.getStateDataLocked()
		room.mu.RUnlock()

		return c.JSON(state)
	})

	// WebSocket upgrade middleware
	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			c.Locals("allowed", true)
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})

	// WebSocket room route
	app.Get("/ws/room/:id", websocket.New(func(c *websocket.Conn) {
		roomID := c.Params("id")
		room, err := h.hub.GetRoom(roomID)
		if err != nil {
			_ = c.WriteJSON(WSMessage{
				Type:  EventError,
				Error: "Room not found: " + roomID,
			})
			_ = c.Close()
			return
		}

		username := c.Query("username", "Viewer")
		if strings.TrimSpace(username) == "" {
			username = "Viewer"
		}
		userID := c.Query("userId", uuid.New().String()[:8])

		wrappedConn := &fiberWSConn{Conn: c}
		client := NewClient(userID, username, room, wrappedConn)

		room.Register(client)
		defer room.Unregister(client)

		// Start write pump
		go client.WritePump()

		// Read pump
		for {
			var msg WSMessage
			if err := c.ReadJSON(&msg); err != nil {
				break
			}
			room.HandleMessage(client, msg)
		}
	}))
}
