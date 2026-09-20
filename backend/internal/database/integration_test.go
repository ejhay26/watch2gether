package database

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
)

func TestSupabaseIntegration(t *testing.T) {
	_ = godotenv.Load("../../.env")
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("DATABASE_URL not set, skipping live Supabase integration test")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	db, err := Connect(ctx, dbURL)
	if err != nil {
		t.Fatalf("Failed to connect to Supabase: %v", err)
	}
	defer db.Close()

	// 1. Create unique test user
	randomSuffix := uuid.New().String()[:8]
	username := fmt.Sprintf("testuser_%s", randomSuffix)
	email := fmt.Sprintf("%s@watchtogether.test", username)
	password := "TestPassword123!"

	user, err := db.CreateUser(ctx, username, email, password)
	if err != nil {
		t.Fatalf("CreateUser failed: %v", err)
	}
	if user.ID == "" || user.Username != username {
		t.Fatalf("Unexpected created user: %+v", user)
	}

	// 2. Query user
	fetchedUser, err := db.GetUserByUsername(ctx, username)
	if err != nil {
		t.Fatalf("GetUserByUsername failed: %v", err)
	}
	if fetchedUser.ID != user.ID {
		t.Errorf("User ID mismatch: got %s, want %s", fetchedUser.ID, user.ID)
	}

	// 3. Save watch history (first time)
	hist := &WatchHistory{
		UserID:           user.ID,
		MediaID:          "demo-sintel",
		Title:            "Sintel",
		Poster:           "https://img.test/sintel.jpg",
		EpisodeID:        "ep1",
		TimestampSeconds: 120,
		DurationSeconds:  900,
	}
	if err := db.SaveHistory(ctx, hist); err != nil {
		t.Fatalf("SaveHistory failed: %v", err)
	}

	// 4. Update watch history (resume test)
	hist.TimestampSeconds = 450
	if err := db.SaveHistory(ctx, hist); err != nil {
		t.Fatalf("SaveHistory update failed: %v", err)
	}

	// 5. Query watch history
	items, err := db.GetHistory(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetHistory failed: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("Expected 1 history item, got %d", len(items))
	}
	if items[0].TimestampSeconds != 450 {
		t.Errorf("Expected updated timestamp 450, got %d", items[0].TimestampSeconds)
	}

	// Cleanup test data
	_ = db.DeleteHistory(ctx, user.ID, "demo-sintel", "ep1")
	_, _ = db.Pool.Exec(ctx, "DELETE FROM users WHERE id = $1", user.ID)
}
