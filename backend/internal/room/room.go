package room

import (
	"sync"
	"time"

	"github.com/google/uuid"
)

type Room struct {
	ID               string
	HostID           string
	MediaID          string
	Title            string
	StreamURL        string
	EpisodeID        string
	PlaybackPosition float64
	IsPlaying        bool
	LastUpdated      time.Time

	clients    map[*Client]bool
	recentChat []ChatMessage
	mu         sync.RWMutex
	onEmpty    func(roomID string)
}

func NewRoom(id, hostID, mediaID, title, streamURL, episodeID string, onEmpty func(roomID string)) *Room {
	return &Room{
		ID:               id,
		HostID:           hostID,
		MediaID:          mediaID,
		Title:            title,
		StreamURL:        streamURL,
		EpisodeID:        episodeID,
		PlaybackPosition: 0,
		IsPlaying:        false,
		LastUpdated:      time.Now().UTC(),
		clients:          make(map[*Client]bool),
		recentChat:       make([]ChatMessage, 0),
		onEmpty:          onEmpty,
	}
}

func (r *Room) CurrentPosition() float64 {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if !r.IsPlaying {
		return r.PlaybackPosition
	}
	elapsed := time.Since(r.LastUpdated).Seconds()
	return r.PlaybackPosition + elapsed
}

func (r *Room) Register(c *Client) {
	r.mu.Lock()
	r.clients[c] = true
	// If room has no active host or this is the first client, designate as host
	if r.HostID == "" || len(r.clients) == 1 {
		r.HostID = c.ID
	}
	state := r.getStateDataLocked()
	r.mu.Unlock()

	// Send current state to newly joined client
	c.Send <- WSMessage{
		Type:      EventRoomState,
		RoomState: state,
	}

	// Notify existing clients that someone joined
	r.Broadcast(WSMessage{
		Type: EventUserJoined,
		User: &Participant{
			ID:       c.ID,
			Username: c.Username,
			IsHost:   c.ID == r.HostID,
			JoinedAt: time.Now().UTC(),
		},
	}, c)
}

func (r *Room) Unregister(c *Client) {
	r.mu.Lock()
	if _, ok := r.clients[c]; !ok {
		r.mu.Unlock()
		return
	}
	delete(r.clients, c)
	c.Close()

	// If host left, elect next available client as host
	if r.HostID == c.ID && len(r.clients) > 0 {
		for remaining := range r.clients {
			r.HostID = remaining.ID
			break
		}
	}

	empty := len(r.clients) == 0
	r.mu.Unlock()

	if empty && r.onEmpty != nil {
		r.onEmpty(r.ID)
		return
	}

	r.Broadcast(WSMessage{
		Type: EventUserLeft,
		User: &Participant{
			ID:       c.ID,
			Username: c.Username,
		},
	}, nil)
}

func (r *Room) HandleMessage(sender *Client, msg WSMessage) {
	switch msg.Type {
	case EventPlay:
		r.mu.Lock()
		r.IsPlaying = true
		r.PlaybackPosition = msg.Position
		r.LastUpdated = time.Now().UTC()
		// Schedule execution 200ms in future for seamless sync
		executeAtMS := time.Now().UTC().Add(200 * time.Millisecond).UnixMilli()
		r.mu.Unlock()

		r.Broadcast(WSMessage{
			Type:        EventPlay,
			Position:    msg.Position,
			ExecuteAtMS: executeAtMS,
		}, nil)

	case EventPause:
		r.mu.Lock()
		r.IsPlaying = false
		r.PlaybackPosition = msg.Position
		r.LastUpdated = time.Now().UTC()
		r.mu.Unlock()

		r.Broadcast(WSMessage{
			Type:     EventPause,
			Position: msg.Position,
		}, nil)

	case EventSeek:
		r.mu.Lock()
		r.PlaybackPosition = msg.Position
		r.LastUpdated = time.Now().UTC()
		executeAtMS := time.Now().UTC().Add(100 * time.Millisecond).UnixMilli()
		r.mu.Unlock()

		r.Broadcast(WSMessage{
			Type:        EventSeek,
			Position:    msg.Position,
			ExecuteAtMS: executeAtMS,
		}, nil)

	case EventChangeMedia:
		r.mu.Lock()
		r.MediaID = msg.MediaID
		r.Title = msg.Title
		r.StreamURL = msg.StreamURL
		r.EpisodeID = msg.EpisodeID
		r.PlaybackPosition = 0
		r.IsPlaying = false
		r.LastUpdated = time.Now().UTC()
		r.mu.Unlock()

		r.Broadcast(WSMessage{
			Type:      EventChangeMedia,
			MediaID:   msg.MediaID,
			Title:     msg.Title,
			StreamURL: msg.StreamURL,
			EpisodeID: msg.EpisodeID,
		}, nil)

	case EventChat:
		if msg.Message == "" {
			return
		}
		chat := ChatMessage{
			ID:        uuid.New().String(),
			UserID:    sender.ID,
			Username:  sender.Username,
			Message:   msg.Message,
			Timestamp: time.Now().UTC(),
		}

		r.mu.Lock()
		r.recentChat = append(r.recentChat, chat)
		if len(r.recentChat) > 50 {
			r.recentChat = r.recentChat[len(r.recentChat)-50:]
		}
		r.mu.Unlock()

		r.Broadcast(WSMessage{
			Type:    EventChat,
			Message: chat.Message,
			User: &Participant{
				ID:       chat.UserID,
				Username: chat.Username,
			},
		}, nil)

	case EventSyncRequest:
		r.mu.RLock()
		state := r.getStateDataLocked()
		r.mu.RUnlock()

		sender.Send <- WSMessage{
			Type:      EventRoomState,
			RoomState: state,
		}
	}
}

func (r *Room) Broadcast(msg WSMessage, skipSender *Client) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for client := range r.clients {
		if skipSender != nil && client == skipSender {
			continue
		}
		select {
		case client.Send <- msg:
		default:
			// Buffer full, drop or handle gracefully
		}
	}
}

func (r *Room) getStateDataLocked() *RoomStateData {
	participants := make([]Participant, 0, len(r.clients))
	for c := range r.clients {
		participants = append(participants, Participant{
			ID:       c.ID,
			Username: c.Username,
			IsHost:   c.ID == r.HostID,
		})
	}

	chatCopy := make([]ChatMessage, len(r.recentChat))
	copy(chatCopy, r.recentChat)

	currPos := r.PlaybackPosition
	if r.IsPlaying {
		currPos += time.Since(r.LastUpdated).Seconds()
	}

	return &RoomStateData{
		RoomID:           r.ID,
		HostID:           r.HostID,
		MediaID:          r.MediaID,
		Title:            r.Title,
		StreamURL:        r.StreamURL,
		EpisodeID:        r.EpisodeID,
		PlaybackPosition: currPos,
		IsPlaying:        r.IsPlaying,
		Participants:     participants,
		RecentChat:       chatCopy,
	}
}
