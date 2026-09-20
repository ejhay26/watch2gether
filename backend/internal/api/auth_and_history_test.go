package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/joho/godotenv"
)

func TestAuthAndHistoryAPI(t *testing.T) {
	_ = godotenv.Load("../../.env")
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("DATABASE_URL not set, skipping API integration test")
	}

	jwtSecret := "test-jwt-secret-api-999"
	db, err := database.Connect(context.Background(), dbURL)
	if err != nil {
		t.Fatalf("Database connection failed: %v", err)
	}
	defer db.Close()

	app := fiber.New()
	authHandler := NewAuthHandler(db, jwtSecret)
	historyHandler := NewHistoryHandler(db, jwtSecret)
	authHandler.RegisterRoutes(app)
	historyHandler.RegisterRoutes(app)

	// 1. Register new user
	suffix := uuid.New().String()[:8]
	username := fmt.Sprintf("apiuser_%s", suffix)
	email := fmt.Sprintf("%s@test.com", username)
	password := "SecretPass123!"

	regBody, _ := json.Marshal(RegisterRequest{
		Username: username,
		Email:    email,
		Password: password,
	})

	req := httptest.NewRequest("POST", "/api/v1/auth/register", bytes.NewReader(regBody))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil || resp.StatusCode != http.StatusCreated {
		t.Fatalf("Register failed: status=%d, err=%v", resp.StatusCode, err)
	}

	var regRes struct {
		Token string `json:"token"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&regRes)
	if regRes.Token == "" {
		t.Fatalf("Expected token in register response")
	}

	// 2. Login
	loginBody, _ := json.Marshal(LoginRequest{
		Username: username,
		Password: password,
	})
	req = httptest.NewRequest("POST", "/api/v1/auth/login", bytes.NewReader(loginBody))
	req.Header.Set("Content-Type", "application/json")
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Login failed: status=%d", resp.StatusCode)
	}

	var loginRes struct {
		Token string `json:"token"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&loginRes)
	token := loginRes.Token

	// 3. Authenticated /me
	req = httptest.NewRequest("GET", "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Me endpoint failed: status=%d", resp.StatusCode)
	}

	// 4. Save Watch History
	histBody, _ := json.Marshal(SaveHistoryRequest{
		MediaID:          "demo-sintel",
		Title:            "Sintel 4K",
		Poster:           "https://img.test/sintel.jpg",
		EpisodeID:        "ep1",
		TimestampSeconds: 320,
		DurationSeconds:  900,
	})
	req = httptest.NewRequest("POST", "/api/v1/history", bytes.NewReader(histBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Save history failed: status=%d", resp.StatusCode)
	}

	// 5. Get Watch History
	req = httptest.NewRequest("GET", "/api/v1/history", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = app.Test(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("Get history failed: status=%d", resp.StatusCode)
	}
	var histList struct {
		History []database.WatchHistory `json:"history"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&histList)
	if len(histList.History) != 1 || histList.History[0].TimestampSeconds != 320 {
		t.Fatalf("Unexpected history results: %+v", histList.History)
	}

	// Cleanup
	_, _ = db.Pool.Exec(context.Background(), "DELETE FROM users WHERE username = $1", username)
}
