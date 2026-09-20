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
└──────────────────┬─────────────────────────────▲─────────────────┘
                   │ REST API                    │ WebSockets
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
│      SUPABASE POSTGRESQL      │    │    CLOUDFLARE R2 (S3)       │
│  - Users & JWT authentication │    │  - Avatars & Profile media  │
│  - Watch History & Resume     │    │  - Subtitle track caching   │
│  - Favorite lists             │    │  - 0 egress fees            │
└───────────────────────────────┘    └─────────────────────────────┘
```

---

## 2. Component Specifications

### A. Backend Service (Go)
* **Framework**: Go with Fiber (or standard net/http / Chi).
* **Binary Size**: ~15–20 MB single static executable. Zero external runtimes or Docker required.
* **RAM Usage**: ~20 MB idle, <50 MB under active multi-room load.
* **Scraper Engine**:
  * Utilizes `goquery` for DOM parsing and `crypto/aes` for decrypting stream manifests from embed hosts.
  * Resolves master `.m3u8` playlists, direct quality tracks (1080p, 720p, 480p), and subtitle tracks (`.vtt` / `.srt`).
* **Room Hub**:
  * Manages active rooms keyed by 6-character alphanumeric codes (e.g., `W2G-941`).
  * Enforces a 200ms future timestamp broadcast window to compensate for client-to-server transit latency.

### B. Database & Auth (Supabase)
* **PostgreSQL Schema**:
  * `profiles`: User identification, username, avatar URL.
  * `watch_history`: Media ID, episode/season, progress in seconds, last watched timestamp.
  * `room_logs`: Historical session records.
* **Inactivity Protection**: Handled via scheduled GitHub Actions ping to prevent 7-day inactivity pause.

### C. Storage (Cloudflare R2)
* S3-compatible object storage for static asset caching and user profile uploads.
* 10 GB free tier with $0 egress bandwidth charges.

### D. Frontend Client (Flutter + media_kit)
* Hardware-accelerated decoding via `libmpv`.
* Clean, non-AI-slop interface with native desktop mouse behaviors and mobile touch ergonomics.
