package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/api"
	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/ejhay26/watch2gether/backend/internal/room"
	"github.com/ejhay26/watch2gether/backend/internal/scraper"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	_ = godotenv.Load(".env", "backend/.env", "../.env", "../../.env")
	if exePath, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exePath)
		_ = godotenv.Load(
			filepath.Join(exeDir, ".env"),
			filepath.Join(exeDir, "..", ".env"),
			filepath.Join(exeDir, "..", "..", ".env"),
		)
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "watch2gether-jwt-default-development-secret-key"
	}

	dbURL := os.Getenv("DATABASE_URL")

	log.Println("Starting Watch2Gether Server with Batteries-Included Security...")

	// 1. Database Connection (Supabase PostgreSQL)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var db *database.DB
	if dbURL != "" {
		var err error
		db, err = database.Connect(ctx, dbURL)
		if err != nil {
			log.Printf("Warning: Database connection failed (%v). Continuing in standalone mode.", err)
		} else {
			log.Println("Connected to Supabase PostgreSQL pooler successfully.")
			defer db.Close()
		}
	} else {
		log.Println("DATABASE_URL not configured. Running without persistent database.")
	}

	// 2. Scraper & Multi-Source Providers (TMDB, HiAnime/Ani-Cli, Video & Audio Engines)
	scraperManager := scraper.NewManager("")

	// 3. Room Hub
	roomHub := room.NewHub()

	// 4. Fiber App Setup with Safe Error Handling
	app := fiber.New(fiber.Config{
		AppName:      "Watch2Gether API v1.0",
		ServerHeader: "Watch2Gether",
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{
				"error":   err.Error(),
				"status":  code,
				"service": "watch2gether-backend",
			})
		},
	})

	// Batteries-Included Security Stack
	app.Use(recover.New(recover.Config{
		EnableStackTrace: false,
	}))
	app.Use(logger.New())
	app.Use(api.SecurityHeaders())
	app.Use(api.InputSanitizer())
	app.Use(api.RateLimiter(120, 1*time.Minute))
	app.Use(cors.New(cors.Config{
		AllowOrigins:     "*",
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS,PATCH",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization, ngrok-skip-browser-warning, X-Requested-With",
		AllowCredentials: false,
	}))

	// 5. Register Routes
	mediaHandler := api.NewMediaHandler(scraperManager)
	mediaHandler.RegisterRoutes(app)

	roomHandler := room.NewRoomHandler(roomHub)
	roomHandler.RegisterRoutes(app)

	if db != nil {
		authHandler := api.NewAuthHandler(db, jwtSecret)
		authHandler.RegisterRoutes(app)

		historyHandler := api.NewHistoryHandler(db, jwtSecret)
		historyHandler.RegisterRoutes(app)

		settingsHandler := api.NewSettingsHandler(db, jwtSecret)
		settingsHandler.RegisterRoutes(app)
	} else {
		app.All("/api/v1/auth/*", func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
				"error":   "Database connection offline. Please check backend DATABASE_URL configuration.",
				"status":  503,
				"service": "watch2gether-backend",
			})
		})
	}

	// App Version & In-App Update API
	app.Get("/api/v1/app/version", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"version": "1.0.2",
			"build_number": 3,
			"release_notes":  "Real movie stream resolutions (eliminated gameplays), persistent room stream rejoining, improved mobile touch responsiveness, and smarter party playback synchronization.",
			"mandatory":      false,
			"android_apk":    "https://github.com/ejhay26/watch2gether/releases/latest/download/app-release.apk",
			"windows_zip":    "https://github.com/ejhay26/watch2gether/releases/latest/download/watchtogether-windows.zip",
		})
	})

	// Root Route
	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"app":       "Watch2Gether Server",
			"status":    "running",
			"security":  "batteries-included (rate-limiting, security-headers, input-sanitizer, panic-recovery)",
			"timestamp": time.Now().UTC(),
			"endpoints": fiber.Map{
				"health":    "/api/v1/health",
				"trending":  "/api/v1/trending",
				"search":    "/api/v1/search?q={query}",
				"rooms":     "/api/v1/rooms",
				"websocket": "/ws/room/:roomId",
			},
		})
	})

	// Graceful shutdown handling
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Listening on http://localhost:%s", port)
		if err := app.Listen(":" + port); err != nil {
			log.Printf("Server error: %v", err)
		}
	}()

	<-stop
	log.Println("Shutting down server gracefully...")
	_ = app.Shutdown()
	log.Println("Server terminated cleanly.")
}
