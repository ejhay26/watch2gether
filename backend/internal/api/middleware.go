package api

import (
	"strings"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
)

// AuthRequired validates Bearer JWT tokens for protected routes
func AuthRequired(jwtSecret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Authorization header is required",
			})
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Authorization header must be Bearer token",
			})
		}

		claims, err := database.ValidateJWT(parts[1], jwtSecret)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid or expired token",
			})
		}

		c.Locals("userID", claims.UserID)
		c.Locals("username", claims.Username)
		return c.Next()
	}
}

// SecurityHeaders applies enterprise-grade security headers (Laravel / Helmet style)
func SecurityHeaders() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Prevent MIME-type sniffing
		c.Set("X-Content-Type-Options", "nosniff")
		// Prevent clickjacking
		c.Set("X-Frame-Options", "SAMEORIGIN")
		// XSS protection for legacy browsers
		c.Set("X-XSS-Protection", "1; mode=block")
		// Restrict referrer data
		c.Set("Referrer-Policy", "strict-origin-when-cross-origin")
		// Restrict hazardous browser features
		c.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		// Content Security Policy default safe directives
		c.Set("X-Download-Options", "noopen")
		c.Set("X-Permitted-Cross-Domain-Policies", "none")
		// Ngrok bypass header
		c.Set("ngrok-skip-browser-warning", "true")

		return c.Next()
	}
}

// RateLimiter implements per-IP request throttling
func RateLimiter(maxRequests int, window time.Duration) fiber.Handler {
	return limiter.New(limiter.Config{
		Max:        maxRequests,
		Expiration: window,
		KeyGenerator: func(c *fiber.Ctx) string {
			// Check X-Forwarded-For or remote IP
			clientIP := c.Get("X-Forwarded-For")
			if clientIP == "" {
				clientIP = c.IP()
			}
			return strings.Split(clientIP, ",")[0]
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"status":  429,
				"error":   "Too many requests. Please slow down.",
				"message": "Rate limit exceeded. Try again in a minute.",
			})
		},
	})
}

// InputSanitizer cleans and protects against injection, path traversal, and null byte attacks
func InputSanitizer() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Sanitize query parameters
		queries := c.Queries()
		for k, val := range queries {
			if strings.Contains(val, "\x00") || strings.Contains(val, "../") || strings.Contains(val, "..\\") {
				return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
					"error": "Invalid request parameter detected",
				})
			}
			// Trim leading and trailing whitespace
			cleaned := strings.TrimSpace(val)
			if cleaned != val {
				c.Request().URI().QueryArgs().Set(k, cleaned)
			}
		}
		return c.Next()
	}
}
