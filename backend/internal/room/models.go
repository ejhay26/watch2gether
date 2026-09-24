package room

import "time"

type EventType string

const (
	EventJoin         EventType = "JOIN"
	EventLeave        EventType = "LEAVE"
	EventRoomState    EventType = "ROOM_STATE"
	EventPlay         EventType = "PLAY"
	EventPause        EventType = "PAUSE"
	EventSeek         EventType = "SEEK"
	EventChangeMedia  EventType = "CHANGE_MEDIA"
	EventChat         EventType = "CHAT"
	EventSyncRequest  EventType = "SYNC_REQUEST"
	EventUserJoined   EventType = "USER_JOINED"
	EventUserLeft     EventType = "USER_LEFT"
	EventError        EventType = "ERROR"
)

type Participant struct {
	ID       string    `json:"id"`
	Username string    `json:"username"`
	IsHost   bool      `json:"is_host"`
	JoinedAt time.Time `json:"joined_at"`
}

type ChatMessage struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Username  string    `json:"username"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

type WSMessage struct {
	Type        EventType      `json:"type"`
	Position    float64        `json:"position,omitempty"`
	ExecuteAtMS int64          `json:"execute_at_ms,omitempty"`
	MediaID     string         `json:"media_id,omitempty"`
	Title       string         `json:"title,omitempty"`
	StreamURL   string         `json:"stream_url,omitempty"`
	EpisodeID   string         `json:"episode_id,omitempty"`
	Headers     map[string]string `json:"headers,omitempty"`
	Message     string         `json:"message,omitempty"`
	RoomState   *RoomStateData `json:"room_state,omitempty"`
	User        *Participant   `json:"user,omitempty"`
	Error       string         `json:"error,omitempty"`
}

type RoomStateData struct {
	RoomID           string        `json:"room_id"`
	HostID           string        `json:"host_id"`
	MediaID          string        `json:"media_id"`
	Title            string        `json:"title"`
	StreamURL        string        `json:"stream_url"`
	EpisodeID        string        `json:"episode_id"`
	Headers          map[string]string `json:"headers,omitempty"`
	PlaybackPosition float64       `json:"playback_position"`
	IsPlaying        bool          `json:"is_playing"`
	Participants     []Participant `json:"participants"`
	RecentChat       []ChatMessage `json:"recent_chat"`
}
