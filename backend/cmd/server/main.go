package main

import (
	"context"
	"log"
	"os"
	"os/signal"
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
	_ = godotenv.Load(".env")
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "watch2gether-jwt-default-development-secret-key"
	}

	dbURL := os.Getenv("DATABASE_URL")

	log.Println("Starting Watch2Gether Server...")

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

	// 2. Scraper & Providers
	scraperManager := scraper.NewManager("")

	// 3. Room Hub
	roomHub := room.NewHub()

	// 4. Fiber App Setup
	app := fiber.New(fiber.Config{
		AppName:      "Watch2Gether API v1.0",
		ServerHeader: "Watch2Gether",
	})

	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins:     "*",
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS,PATCH",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization, ngrok-skip-browser-warning, X-Requested-With",
		AllowCredentials: false,
	}))

	// Middleware to handle ngrok browser warning bypass header for all responses
	app.Use(func(c *fiber.Ctx) error {
		c.Set("ngrok-skip-browser-warning", "true")
		return c.Next()
	})

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
	}

	// Root Route
	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"app":       "Watch2Gether Server",
			"status":    "running",
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
