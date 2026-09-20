package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load(".env")
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL not set in .env")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	fmt.Println("Connecting to Supabase Pooler...")
	db, err := database.Connect(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	fmt.Println("SUCCESS: Connected and migrated Supabase PostgreSQL schema!")
}
