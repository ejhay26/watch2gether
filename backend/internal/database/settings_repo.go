package database

import (
	"context"
	"fmt"
	"time"
)

func (db *DB) SaveSettings(ctx context.Context, s *UserSettings) error {
	s.UpdatedAt = time.Now().UTC()

	query := `
		INSERT INTO user_settings (user_id, liquid_glass, auto_sync_party, hardware_accel, subtitles_enabled, default_quality, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (user_id)
		DO UPDATE SET
			liquid_glass = EXCLUDED.liquid_glass,
			auto_sync_party = EXCLUDED.auto_sync_party,
			hardware_accel = EXCLUDED.hardware_accel,
			subtitles_enabled = EXCLUDED.subtitles_enabled,
			default_quality = EXCLUDED.default_quality,
			updated_at = EXCLUDED.updated_at
	`

	_, err := db.Pool.Exec(ctx, query,
		s.UserID,
		s.LiquidGlass,
		s.AutoSyncParty,
		s.HardwareAccel,
		s.SubtitlesEnabled,
		s.DefaultQuality,
		s.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to save user settings: %w", err)
	}

	return nil
}

func (db *DB) GetSettings(ctx context.Context, userID string) (*UserSettings, error) {
	query := `
		SELECT user_id, liquid_glass, auto_sync_party, hardware_accel, subtitles_enabled, default_quality, updated_at
		FROM user_settings
		WHERE user_id = $1
	`

	var s UserSettings
	err := db.Pool.QueryRow(ctx, query, userID).Scan(
		&s.UserID,
		&s.LiquidGlass,
		&s.AutoSyncParty,
		&s.HardwareAccel,
		&s.SubtitlesEnabled,
		&s.DefaultQuality,
		&s.UpdatedAt,
	)
	if err != nil {
		// Return default settings if none found
		return &UserSettings{
			UserID:           userID,
			LiquidGlass:      true,
			AutoSyncParty:    true,
			HardwareAccel:    true,
			SubtitlesEnabled: true,
			DefaultQuality:   "Auto",
			UpdatedAt:        time.Now().UTC(),
		}, nil
	}

	return &s, nil
}
