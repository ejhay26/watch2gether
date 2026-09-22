# Watch2Gether Ralph Loop Backlog

Overall Goal: Full-stack, multiplatform ad-free streaming, anime/cartoons/shows support, YouTube-style player layout, in-player episode navigation, batteries-included Go security, and zero fallback short videos.
Target Architecture: Go (Fiber) Backend (Local + Ngrok Tunnel), Ani-cli / HiAnime scraper engine with otaku-embed-v1 XOR decryption, Supabase (PostgreSQL & Auth), Flutter Frontend (Windows/Android).
Current Status: All Ralph Loop Tasks Completed & Verified Live <!-- GOAL_COMPLETE -->

## Loop 1: Eliminate All Fake Fallback Videos & Block Handling
- [x] 1.1 Remove all hardcoded instances of Tears of Steel from `media_overview_modal.dart`, `tmdb_feature_provider.go`, and `engine.go`.
- [x] 1.2 Implement transparent error reporting when a stream cannot be resolved instead of silently substituting unrelated videos.

## Loop 2: Ani-Cli & HiAnime Multi-Source Scraper Engine (Anime, Cartoons & TV Shows)
- [x] 2.1 Research and analyze `MovieBox-TUI` (Showbox HMAC-MD5 signing, aoneroom host pool, Stremio addon aggregation) and `ani-cli` (HiAnime base API, episode endpoints, ZokoAnime otaku-embed-v1 XOR deobfuscation).
- [x] 2.2 Implement HiAnime scraper in backend:
  - Search anime and cartoons (`https://hianime.at/search?keyword=`)
  - Parse full episode lists (`/api/theme/episode/list/{id}`)
  - Resolve Sub and Dub servers (`/api/theme/episode/servers?episodeId=`)
  - Extract decrypted 1080p HLS master `.m3u8` and English `.vtt` subtitles via `otaku-embed-v1` XOR decoding.
- [x] 2.3 Expose anime & cartoon catalog in search, details, episodes, and sources.

## Loop 3: Go Framework Batteries-Included Security Layer
- [x] 3.1 Implement Fiber rate limiting (`limiter` middleware) per client IP (120 req/min).
- [x] 3.2 Implement Fiber security headers (`helmet` style: X-Content-Type-Options: nosniff, X-Frame-Options: SAMEORIGIN, Permissions-Policy, Referrer-Policy, ngrok bypass).
- [x] 3.3 Implement input sanitization (null byte, path traversal protection) and panic recovery middleware in Fiber.
- [x] 3.4 Verify backend health and security headers via HTTP test.

## Loop 4: In-Player Seasons & Episodes Navigation & Player UX
- [x] 4.1 Update double-tap seek to 5 seconds (was 10s) in `desktop_hud.dart` and `mobile_gestures.dart`.
- [x] 4.2 Make volume slider wider (140px width) in `desktop_hud.dart`.
- [x] 4.3 Build Seasons & Episodes sidebar drawer in `player_screen.dart`:
  - Show Season dropdown / selector.
  - List all episodes with number, title, and current playing indicator.
  - One-tap episode switching without leaving the player.
  - Works seamlessly in both fullscreen and windowed modes.

## Loop 5: YouTube-Style Windowed Player Layout
- [x] 5.1 Implement YouTube-style responsive layout in `player_screen.dart` when not in fullscreen:
  - Desktop/wide view: video player on left (16:9), recommended titles / up next queue on right sidebar.
  - Mobile/narrow view: video player on top (16:9), recommended titles / episodes below.
  - In fullscreen mode: video player occupies full viewport with slide-over drawers for Chat and Episodes.
- [x] 5.2 Add category filter chips on Home Screen ("🔥 All & Trending", "⛩️ Anime & Animation", "🎬 Movies", "📺 TV Series").

## Loop 6: End-to-End Build & Visual Verification
- [x] 6.1 Compile Go backend (`server.exe`) and restart service on port 8080 and ngrok.
- [x] 6.2 Build Flutter Windows application (`watch2gether.exe`).
- [x] 6.3 Test playback across anime, cartoons, series, and movies (Arcane, Naruto, One Piece).
- [x] 6.4 Verify zero fallback videos, double-tap 5s seek, wide volume slider, and YouTube-style windowed layout.
- [x] 6.5 Commit all changes to Git and push to origin.
