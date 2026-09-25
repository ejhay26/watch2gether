package database

import "time"

type User struct {
	ID           string    `json:"id"`
	Username     string    `json:"username"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type WatchHistory struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	MediaID          string    `json:"media_id"`
	Title            string    `json:"title"`
	Poster           string    `json:"poster"`
	EpisodeID        string    `json:"episode_id,omitempty"`
	TimestampSeconds int       `json:"timestamp_seconds"`
	DurationSeconds  int       `json:"duration_seconds"`
	IsWatched        bool      `json:"is_watched"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type UserSettings struct {
	UserID           string    `json:"user_id"`
	LiquidGlass      bool      `json:"liquid_glass"`
	AutoSyncParty    bool      `json:"auto_sync_party"`
	HardwareAccel    bool      `json:"hardware_accel"`
	SubtitlesEnabled bool      `json:"subtitles_enabled"`
	DefaultQuality   string    `json:"default_quality"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type Favorite struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	MediaID   string    `json:"media_id"`
	Title     string    `json:"title"`
	Poster    string    `json:"poster"`
	CreatedAt time.Time `json:"created_at"`
}

type RoomSession struct {
	ID               string    `json:"id"`
	HostID           string    `json:"host_id,omitempty"`
	MediaID          string    `json:"media_id"`
	Title            string    `json:"title"`
	StreamURL        string    `json:"stream_url,omitempty"`
	PlaybackPosition int       `json:"playback_position"`
	IsPlaying        bool      `json:"is_playing"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}
