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
			DisableStartupMessage: true,
		})
		fiberApp.Use(recover.New())
		fiberApp.Use(cors.New(cors.Config{
			AllowOrigins: "*",
			AllowHeaders: "*",
		}))

		scraperMgr := scraper.NewManager()
		roomMgr := room.NewManager()

		// Connect to Supabase if DATABASE_URL is configured, or run in local standalone mode
		dbURL := os.Getenv("DATABASE_URL")
		var db *database.Database
		if dbURL != "" {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			db, _ = database.Connect(ctx, dbURL)
		}

		jwtSecret := "super-secret-jwt-key-watch2gether-2026-production"
		api.SetupRoutes(fiberApp, scraperMgr, roomMgr, db, jwtSecret)

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
