# Watch2Gether Architecture & Technical Specification

Watch2Gether is a full-stack, cross-platform media streaming and synchronized viewing platform designed for private, high-performance, and ad-free playback across desktop and mobile devices.

---

## 1. System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                   FLUTTER CLIENT (DESKTOP & MOBILE)              │
│  - Windows, macOS, Linux, Android, iOS                           │
│  - Video Core: media_kit (libmpv hardware decoding)              │
│  - Desktop UX: Hover-to-reveal controls, auto-hide, MPV hotkeys  │
│  - Mobile UX: Double-tap seek, brightness & volume gestures      │
│  - Auto-bypasses ngrok warning via ngrok-skip-browser-warning    │
└──────────────────┬─────────────────────────────▲─────────────────┘
                   │ REST API                    │ WebSockets
                   ▼                             │
┌────────────────────────────────────────────────┴─────────────────┐
│     PERSISTENT NGROK SECURE TUNNEL (HTTPS & WSS)                 │
│     https://nuclei-oil-modular.ngrok-free.dev                    │
└──────────────────┬─────────────────────────────▲─────────────────┘
                   ▼                             │
┌────────────────────────────────────────────────┴─────────────────┐
│                    GOLANG BACKEND SERVICE                        │
│                                                                  │
│  ┌───────────────────────┐             ┌──────────────────────┐  │
│  │  Scraper Engine       │             │  WebSocket Room Hub  │  │
│  │  - AES key decryptor  │             │  - Room lifecycle    │  │
│  │  - m3u8 playlist parse│             │  - Timestamp sync    │  │
│  │  - Subtitle extract   │             │  - In-room chat      │  │
│  └───────────┬───────────┘             └──────────┬───────────┘  │
└──────────────┼────────────────────────────────────┼──────────────┘
               │                                    │
               ▼                                    ▼
┌───────────────────────────────┐    ┌─────────────────────────────┐
│      SUPABASE POSTGRESQL      │    │    ONLINE CLOUD CI/CD       │
│  - Users & JWT authentication │    │  - GitHub Actions APK build │
│  - Watch History & Resume     │    │  - Compiles release APK     │
│  - Favorite lists             │    │  - 0 disk space on local PC │
└───────────────────────────────┘    └─────────────────────────────┘
```

---

## 2. Component Specifications

### A. Infrastructure & Networking
* **Backend Host**: High-performance local Go service listening on `:8080`.
* **Public Tunnel**: `https://nuclei-oil-modular.ngrok-free.dev` providing global HTTPS & WSS access.
* **Header Bypass**: `ngrok-skip-browser-warning: true` injected on all Flutter client API & WebSocket handshakes.

### B. Backend Service (Go)
* **Framework**: Go with Fiber.
* **Memory Footprint**: ~25 MB RAM.
* **Scraper Engine**:
  * Utilizes `goquery` for DOM parsing and `crypto/aes` for decrypting stream manifests from embed hosts.
  * Resolves master `.m3u8` playlists, direct quality tracks (1080p, 720p, 480p), and subtitle tracks (`.vtt` / `.srt`).
* **Room Hub**:
  * Manages active rooms keyed by 6-character alphanumeric codes (e.g., `W2G-941`).
  * Enforces a 200ms future timestamp broadcast window to compensate for client-to-server transit latency.

### C. Database & Auth (Supabase)
* **PostgreSQL Schema**:
  * `profiles`: User identification, username, avatar URL.
  * `watch_history`: Media ID, episode/season, progress in seconds, last watched timestamp.
  * `room_logs`: Historical session records.
* **IPv4 Pooler**: Connects via `aws-0-ap-southeast-1.pooler.supabase.com:6543`.

### D. Frontend Client (Flutter + media_kit)
* Hardware-accelerated decoding via `libmpv`.
* Clean, non-AI-slop interface with native desktop mouse behaviors and mobile touch ergonomics.
* GitHub Actions workflow builds Android release APKs online for free without needing local Android Studio.
