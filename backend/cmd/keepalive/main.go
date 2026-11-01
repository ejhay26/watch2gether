package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		fmt.Println("Error: DATABASE_URL environment variable is required")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	config, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		fmt.Printf("Config error: %v\n", err)
		os.Exit(1)
	}

	// Essential for Supabase PgBouncer pooler in transaction mode
	config.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		fmt.Printf("Connection error: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()

	var now time.Time
	err = pool.QueryRow(ctx, "SELECT NOW();").Scan(&now)
	if err != nil {
		fmt.Printf("Query error: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("SUCCESS: Supabase heartbeat query executed at %v. Inactivity timer reset.\n", now)
}
