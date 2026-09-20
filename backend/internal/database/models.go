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
