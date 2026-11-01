package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"github.com/ejhay26/watch2gether/backend/internal/api"
	"github.com/ejhay26/watch2gether/backend/internal/database"
	"github.com/ejhay26/watch2gether/backend/internal/room"
	"github.com/ejhay26/watch2gether/backend/internal/scraper"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

var (
	appOnce  sync.Once
	fiberApp *fiber.App
)

//export StartServer
func StartServer(port C.int) C.int {
	appOnce.Do(func() {
		p := int(port)
		if p <= 0 {
			p = 8080
		}

		// Verify if port is already listening
		conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", p), 150*time.Millisecond)
		if err == nil {
			conn.Close()
			log.Printf("[Go Mobile] Port %d is already occupied, skipping startup.", p)
			return
		}

		fiberApp = fiber.New(fiber.Config{
			AppName:               "Watch2Gether Embedded Mobile Engine",
			DisableStartupMessage: true,
			ErrorHandler: func(c *fiber.Ctx, err error) error {
				code := fiber.StatusInternalServerError
				if e, ok := err.(*fiber.Error); ok {
					code = e.Code
				}
				return c.Status(code).JSON(fiber.Map{
					"error":   err.Error(),
					"status":  code,
					"service": "watch2gether-embedded",
				})
			},
		})
		fiberApp.Use(recover.New(recover.Config{
			EnableStackTrace: false,
		}))
		fiberApp.Use(cors.New(cors.Config{
			AllowOrigins: "*",
			AllowHeaders: "*",
		}))

		scraperMgr := scraper.NewManager("")
		roomHub := room.NewHub()

		// Connect to Supabase if DATABASE_URL is configured, or run in local standalone mode
		dbURL := os.Getenv("DATABASE_URL")
		var db *database.DB
		if dbURL != "" {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			db, _ = database.Connect(ctx, dbURL)
		}

		jwtSecret := os.Getenv("JWT_SECRET")
		if jwtSecret == "" {
			jwtSecret = "super-secret-jwt-key-watch2gether-mobile-embedded"
		}

		// Register routes
		mediaHandler := api.NewMediaHandler(scraperMgr)
		mediaHandler.RegisterRoutes(fiberApp)

		roomHandler := room.NewRoomHandler(roomHub)
		roomHandler.RegisterRoutes(fiberApp)

		if db != nil {
			authHandler := api.NewAuthHandler(db, jwtSecret)
			authHandler.RegisterRoutes(fiberApp)

			historyHandler := api.NewHistoryHandler(db, jwtSecret)
			historyHandler.RegisterRoutes(fiberApp)

			settingsHandler := api.NewSettingsHandler(db, jwtSecret)
			settingsHandler.RegisterRoutes(fiberApp)
		} else {
			fiberApp.Post("/api/v1/auth/login", func(c *fiber.Ctx) error {
				var body struct {
					Username string `json:"username"`
				}
				_ = c.BodyParser(&body)
				if body.Username == "" {
					body.Username = "MobileHost"
				}
				return c.JSON(fiber.Map{
					"token": "peer_token_" + body.Username,
					"user": fiber.Map{
						"id":       "peer_" + body.Username,
						"username": body.Username,
						"email":    body.Username + "@mesh.local",
						"role":     "host",
					},
				})
			})
		}

		go func() {
			addr := fmt.Sprintf("127.0.0.1:%d", p)
			log.Printf("[Go Mobile] Embedded companion server starting on %s...", addr)
			if err := fiberApp.Listen(addr); err != nil {
				log.Printf("[Go Mobile] Listen error: %v", err)
			}
		}()
	})
	return 0
}

//export StopServer
func StopServer() C.int {
	if fiberApp != nil {
		_ = fiberApp.Shutdown()
		return 0
	}
	return -1
}

// JNI_OnLoad is invoked automatically by Android's System.loadLibrary("go_backend")
//
//export JNI_OnLoad
func JNI_OnLoad(vm uintptr, reserved uintptr) int {
	log.Println("[Go Mobile] libgo_backend.so loaded via JNI. Starting embedded Go engine...")
	StartServer(8080)
	return 0x00010006 // JNI_VERSION_1_6
}

func main() {}
