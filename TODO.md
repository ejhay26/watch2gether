# Watch2Gether Ralph Loop Backlog (Updated Iteration)

Overall Goal: Eliminate all blocked fallbacks, fix movie/TV stream scrapers, report Consumet findings, implement Dub/Sub selector, fix category tags, YouTube-style player (sidebar Up Next, below-player episode grid), fix click bleed-through, upward dropdowns, remove all emojis, and apply premium Electric Indigo color palette.
Current Status: Ralph Loop Active Execution - Loop 11 Final Build & Verification

## Loop 7: Consumet Investigation & Real Movie/TV Stream Scraper
- [x] 7.1 Report on Consumet: Tested all 5 movie providers in `@consumet/extensions` (FlixHQ, Goku, SFlix, HiMovies, DramaCool) -> All failed with HTTP 522 Cloudflare blocks or ECONNREFUSED.
- [x] 7.2 Remove all hardcoded Tears of Steel and Big Buck Bunny references from `backend/internal/engine/video/tmdb_feature_provider.go` and `video/engine.go`.
- [x] 7.3 Implement dynamic Archive.org full movie scraper in `ArchiveProvider`:
  - Search Archive.org movies by title and year.
  - Inspect files metadata for feature MP4/MKV (> 250MB).
  - Stream real 1080p/720p movies (verified working for Rush Hour 1, 2, 3, etc.).
- [x] 7.4 Multi-source streaming fallback for modern films & TV shows with transparent error handling (no fallback short videos).

## Loop 8: Tagging, Category & Sub/Dub Audio Precision
- [x] 8.1 Fix media categorization: Movies must never display "Series / Anime", "EP 1", or episode panels.
- [x] 8.2 Implement Dub vs Sub selection for anime (e.g. Frieren):
  - Parse both `[SUB]` (Japanese) and `[DUB]` (English) servers from HiAnime/ZokoAnime.
  - Add explicit Dub / Sub version toggle in `media_overview_modal.dart`.
  - In `desktop_hud.dart` audio selector: list `[DUB] English Dub` and `[SUB] Japanese Audio` and switch server live while preserving timestamp.
- [x] 8.3 Handle multi-season anime indexing (e.g. Frieren Season 1 and Season 2).

## Loop 9: Color Scheme, Palette & UI Anti-Slop (No Emojis)
- [x] 9.1 Remove all emojis across the UI (replace with clean, professional typography: "All", "Anime & Animation", "Movies", "TV Series").
- [x] 9.2 Refactor `frontend/lib/constants/theme.dart` with an ultra-premium Electric Indigo / Sapphire & Deep Obsidian palette:
  - Background: `#090B10`
  - Surface: `#0F131C`
  - Surface Elevated: `#161B26`
  - Surface Border: `#232B3C`
  - Accent: `#6366F1` (Indigo Sapphire)
  - Accent Bright: `#818CF8`
  - Rating Amber: `#F59E0B`
  - Text Primary: `#F8FAFC`, Muted: `#94A3B8`
- [x] 9.3 Apply theme consistently across all modals, home screen, player HUD, and drawers.

## Loop 10: Player Layout, Below-Player Episode Grid & Click Bleed-Through Fix
- [x] 10.1 In windowed mode:
  - Right sidebar: ONLY display "Up Next" (recommended films).
  - Below video player: Season dropdown/chips + Seasons & Episodes displayed as an organized, sleek GRID (not overflowing horizontal scroll).
- [x] 10.2 In fullscreen mode:
  - Seasons & Episodes accessible via sliding sidebar drawer from HUD icon button.
- [x] 10.3 Fix click bleed-through:
  - Isolate pointer events in sliding drawers with `GestureDetector(behavior: HitTestBehavior.opaque)` and `IgnorePointer` so clicks do not trigger underlying controls (e.g. Watch Together button).
  - Remove redundant "Watch Together" button from HUD top bar in windowed mode.
- [x] 10.4 Fix dropdown directions:
  - Ensure HUD bottom bar popup menus open upward naturally above the bar (`PopupMenuPosition.over`).
  - Ensure season selector opens in the natural direction without glitchy offsets.

## Loop 11: End-to-End Build, Verification & Release
- [x] 11.1 Recompile backend `server.exe` and test live endpoints (Rush Hour, Frieren Dub/Sub, Arcane).
- [ ] 11.2 Rebuild Flutter Windows application (`watch2gether.exe`).
- [ ] 11.3 Verify playback across movies, anime, and series.
- [ ] 11.4 Commit all changes to Git and push to origin.
