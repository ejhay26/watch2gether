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
│        ORACLE CLOUD ALWAYS FREE DEDICATED VM (24/7)              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    GOLANG BACKEND SERVICE                  │  │
│  │  ┌───────────────────────┐       ┌──────────────────────┐  │  │
│  │  │  Scraper Engine       │       │  WebSocket Room Hub  │  │  │
│  │  │  - AES key decryptor  │       │  - Room lifecycle    │  │  │
│  │  │  - m3u8 playlist parse│       │  - Timestamp sync    │  │  │
│  │  │  - Subtitle extract   │       │  - In-room chat      │  │  │
│  │  └───────────┬───────────┘       └──────────┬───────────┘  │  │
│  └──────────────┼──────────────────────────────┼──────────────┘  │
│                 ▼                              ▼                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                NATIVE POSTGRESQL DATABASE                  │  │
│  │  - Users, JWT authentication, Profiles                     │  │
│  │  - Watch History & Resume Progress                         │  │
│  │  - Fast local socket access (<0.5ms latency)               │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │             ANTI-IDLE KEEP-ALIVE SYSTEM SERVICE            │  │
│  │  - Guarantees VM activity to bypass Oracle reclamation     │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Specifications

### A. Dedicated Infrastructure (Oracle Cloud Always Free)
* **Compute**: Ampere A1 ARM (up to 4 OCPUs, 24 GB RAM) or AMD Compute VM.
* **Storage**: 200 GB NVMe block storage.
* **Networking**: 10 TB free monthly bandwidth, dedicated public IPv4 address.
* **Continuous Uptime**: Native Linux server running 24/7 with zero sleep or cold-start latency.

### B. Backend Service (Go)
* **Framework**: Go with Fiber.
* **Binary Size**: ~15–20 MB single static executable. Zero external runtimes or Docker required.
* **RAM Usage**: ~20 MB idle, <50 MB under active multi-room load.
* **Scraper Engine**:
  * Utilizes `goquery` for DOM parsing and `crypto/aes` for decrypting stream manifests from embed hosts.
  * Resolves master `.m3u8` playlists, direct quality tracks (1080p, 720p, 480p), and subtitle tracks (`.vtt` / `.srt`).
* **Room Hub**:
  * Manages active rooms keyed by 6-character alphanumeric codes (e.g., `W2G-941`).
  * Enforces a 200ms future timestamp broadcast window to compensate for client-to-server transit latency.

### C. Database (Native PostgreSQL on VM)
* Runs directly on the Oracle VM alongside the Go binary.
* Eliminates third-party API quotas, sleep timers, and internet network hops.

### D. Frontend Client (Flutter + media_kit)
* Hardware-accelerated decoding via `libmpv`.
* Clean, non-AI-slop interface with native desktop mouse behaviors and mobile touch ergonomics.
