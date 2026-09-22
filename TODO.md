# Watch2Gether Ralph Loop Backlog

Overall Goal: Full-stack, multiplatform ad-free streaming and Watch Together ecosystem.
Target Architecture: Go (Fiber) Backend (Local + Ngrok Tunnel), Supabase (PostgreSQL & Auth), Flutter Frontend (Windows/Android).
Current Status: Ralph Loop Iterative Execution Complete

## Loop 1: Fix Catalog Poster Thumbnails & Metadata Visuals
- [x] 1.1 Audit all catalog card poster URLs in ackend/internal/engine/video/archive_provider.go and catalog/engine.go.
- [x] 1.2 Replace broken TMDB poster URLs with verified, high-resolution working image links (TMDB API / Wikimedia Commons).
- [x] 1.3 Verify every catalog item poster returns HTTP 200 image/jpeg or image/png (16/16 verified).
- [x] 1.4 Test on running Flutter app and verify cards render without placeholder slate icons.

## Loop 2: Fix Player HUD & Windows Fullscreen Toggle
- [x] 2.1 Remove redundant maximize button and onToggleMaximize from rontend/lib/ui/player/desktop_hud.dart.
- [x] 2.2 Fix Fullscreen logic in rontend/lib/ui/player/player_screen.dart:
  - When window is maximized, properly unmaximize before calling setFullScreen(true).
  - When exiting fullscreen, restore previous window state (maximized or normal).
  - Ensure hotkey 'F' and HUD fullscreen button both work identically in small windowed and maximized modes.
- [x] 2.3 Verify lutter test passes (5/5 tests passing).
- [x] 2.4 Verify on running Windows desktop window.

## Loop 3: Resilient Multi-Source Streaming Engine (FlixHQ & Ani-Cli Style Multi-Provider)
- [x] 3.1 Investigate active FlixHQ mirrors (https://flixhq.ws), episode AJAX endpoints, and server embed links.
- [x] 3.2 Implement FlixHQ real scraper resolution in TMDBFeatureProvider (movies and series).
- [x] 3.3 Add multi-source resilience (Archive.org search, Unified Streaming HLS, High-Speed CDN).
- [x] 3.4 Eliminate broken Invidious / YouTube clip fallbacks that result in infinite loading buffers.
- [x] 3.5 Test stream extraction for TV series (e.g. *Reacher* S01E01) and feature films, validating HTTP 200/206 stream headers.

## Loop 4: End-to-End Validation Across 15+ Titles on Real App
- [x] 4.1 Recompile Go backend (server.exe) and restart backend service.
- [x] 4.2 Recompile Flutter Windows desktop application (watch2gether.exe) and launch.
- [x] 4.3 Test playback across 18 distinct films and series (18/18 verified streaming video bytes over HTTP 206, zero infinite buffering).
- [x] 4.4 Verify fullscreen toggle on real app in both windowed and maximized modes.
- [x] 4.5 Capture visual verification and automated integration test results.
- [x] 4.6 Commit all changes to Git and push to origin.
