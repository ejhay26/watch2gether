package room

import (
	"crypto/rand"
	"errors"
	"fmt"
	"strings"
	"sync"
)

type Hub struct {
	rooms map[string]*Room
	mu    sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		rooms: make(map[string]*Room),
	}
}

func GenerateRoomCode() string {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Exclude confusing chars I, 1, O, 0
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = charset[int(b[i])%len(charset)]
	}
	return string(b)
}

func (h *Hub) CreateRoom(hostID, mediaID, title, streamURL, episodeID string) *Room {
	h.mu.Lock()
	defer h.mu.Unlock()

	var code string
	for {
		code = GenerateRoomCode()
		if _, exists := h.rooms[code]; !exists {
			break
		}
	}

	room := NewRoom(code, hostID, mediaID, title, streamURL, episodeID, func(roomID string) {
		h.DeleteRoom(roomID)
	})

	h.rooms[code] = room
	return room
}

func (h *Hub) GetRoom(id string) (*Room, error) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	roomCode := strings.ToUpper(strings.TrimSpace(id))
	room, exists := h.rooms[roomCode]
	if !exists {
		return nil, errors.New("room not found")
	}
	return room, nil
}

func (h *Hub) DeleteRoom(id string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	roomCode := strings.ToUpper(strings.TrimSpace(id))
	if room, exists := h.rooms[roomCode]; exists {
		delete(h.rooms, roomCode)
		fmt.Printf("Room %s destroyed (empty)\n", roomCode)
		_ = room
	}
}

func (h *Hub) RoomCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.rooms)
}
