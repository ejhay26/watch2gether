package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	Pool *pgxpool.Pool
}

func Connect(ctx context.Context, connString string) (*DB, error) {
	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database config: %w", err)
	}

	config.MaxConns = 5
	config.MinConns = 1
	config.MaxConnLifetime = 1 * time.Hour
	config.MaxConnIdleTime = 10 * time.Minute

	// Essential for PgBouncer / Supabase connection poolers in transaction mode:
	config.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create pool: %w", err)
	}

	// Verify ping
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	db := &DB{Pool: pool}
	if err := db.Migrate(ctx); err != nil {
		log.Printf("Warning: Database migration had issues: %v", err)
		return nil, err
	}

	return db, nil
}

func (db *DB) Migrate(ctx context.Context) error {
	schema := `
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY,
		username TEXT UNIQUE NOT NULL,
		email TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS watch_history (
		id TEXT PRIMARY KEY,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		media_id TEXT NOT NULL,
		title TEXT NOT NULL,
		poster TEXT,
		episode_id TEXT,
		timestamp_seconds INT NOT NULL DEFAULT 0,
		duration_seconds INT NOT NULL DEFAULT 0,
		updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
		CONSTRAINT unique_user_media_ep UNIQUE (user_id, media_id, episode_id)
	);

	CREATE TABLE IF NOT EXISTS favorites (
		id TEXT PRIMARY KEY,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		media_id TEXT NOT NULL,
		title TEXT NOT NULL,
		poster TEXT,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
		CONSTRAINT unique_user_favorite UNIQUE (user_id, media_id)
	);

	CREATE TABLE IF NOT EXISTS room_sessions (
		id TEXT PRIMARY KEY,
		host_id TEXT,
		media_id TEXT NOT NULL,
		title TEXT NOT NULL,
		stream_url TEXT,
		playback_position INT NOT NULL DEFAULT 0,
		is_playing BOOLEAN NOT NULL DEFAULT false,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
		updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);
	`

	_, err := db.Pool.Exec(ctx, schema)
	if err != nil {
		return fmt.Errorf("migration query error: %w", err)
	}
	return nil
}

func (db *DB) Close() {
	if db.Pool != nil {
		db.Pool.Close()
	}
}
