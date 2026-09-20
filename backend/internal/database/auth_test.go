package database

import (
	"testing"
	"time"
)

func TestPasswordHashing(t *testing.T) {
	password := "SecretP@ssword123!"
	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("Failed to hash password: %v", err)
	}

	if !CheckPasswordHash(password, hash) {
		t.Errorf("Password hash check failed for correct password")
	}

	if CheckPasswordHash("WrongPassword!", hash) {
		t.Errorf("Password hash check succeeded for incorrect password")
	}
}

func TestJWTGenerationAndValidation(t *testing.T) {
	secret := "test-secret-key-12345"
	userID := "user-uuid-123"
	username := "streammaster"

	// 1. Valid token
	token, err := GenerateJWT(userID, username, secret, 1*time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate JWT: %v", err)
	}

	claims, err := ValidateJWT(token, secret)
	if err != nil {
		t.Fatalf("Failed to validate JWT: %v", err)
	}
	if claims.UserID != userID || claims.Username != username {
		t.Errorf("Claims mismatch: got (%s, %s), want (%s, %s)", claims.UserID, claims.Username, userID, username)
	}

	// 2. Invalid secret
	_, err = ValidateJWT(token, "wrong-secret-key")
	if err == nil {
		t.Errorf("Expected error validating with wrong secret")
	}

	// 3. Expired token
	expiredToken, err := GenerateJWT(userID, username, secret, -1*time.Minute)
	if err != nil {
		t.Fatalf("Failed to generate expired JWT: %v", err)
	}
	_, err = ValidateJWT(expiredToken, secret)
	if err == nil {
		t.Errorf("Expected error validating expired token")
	}
}
