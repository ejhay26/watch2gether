package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
)

func (db *DB) SaveHistory(ctx context.Context, h *WatchHistory) error {
	if h.ID == "" {
		h.ID = uuid.New().String()
	}
	h.UpdatedAt = time.Now().UTC()

	query := `
		INSERT INTO watch_history (id, user_id, media_id, title, poster, episode_id, timestamp_seconds, duration_seconds, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (user_id, media_id, episode_id)
		DO UPDATE SET
			timestamp_seconds = EXCLUDED.timestamp_seconds,
			duration_seconds = EXCLUDED.duration_seconds,
			updated_at = EXCLUDED.updated_at
	`

	_, err := db.Pool.Exec(ctx, query,
		h.ID,
		h.UserID,
		h.MediaID,
		h.Title,
		h.Poster,
		h.EpisodeID,
		h.TimestampSeconds,
		h.DurationSeconds,
		h.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to save watch history: %w", err)
	}

	return nil
}

func (db *DB) GetHistory(ctx context.Context, userID string) ([]WatchHistory, error) {
	query := `
		SELECT id, user_id, media_id, title, poster, episode_id, timestamp_seconds, duration_seconds, updated_at
		FROM watch_history
		WHERE user_id = $1
		ORDER BY updated_at DESC
		LIMIT 50
	`

	rows, err := db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query watch history: %w", err)
	}
	defer rows.Close()

	var history []WatchHistory
	for rows.Next() {
		var item WatchHistory
		var episodeID *string
		err := rows.Scan(
			&item.ID,
			&item.UserID,
			&item.MediaID,
			&item.Title,
			&item.Poster,
			&episodeID,
			&item.TimestampSeconds,
			&item.DurationSeconds,
			&item.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		if episodeID != nil {
			item.EpisodeID = *episodeID
		}
		history = append(history, item)
	}

	return history, nil
}

func (db *DB) DeleteHistory(ctx context.Context, userID, mediaID, episodeID string) error {
	query := `
		DELETE FROM watch_history
		WHERE user_id = $1 AND media_id = $2 AND episode_id = $3
	`
	_, err := db.Pool.Exec(ctx, query, userID, mediaID, episodeID)
	return err
}
