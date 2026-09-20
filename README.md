# Watch2Gether

A lightweight, high-performance, and ad-free multiplatform streaming and synchronized Watch Together ecosystem.

## Stack Overview
* **Backend**: Go (Fiber) - Single static binary, low memory footprint (~25MB), zero Docker required.
* **Frontend**: Flutter - Cross-platform client for Android, iOS, macOS, Windows, and Linux with hardware-accelerated video decoding (`media_kit` / `libmpv`).
* **Database & Auth**: Supabase (PostgreSQL + JWT Authentication).
* **Storage**: Cloudflare R2 (S3-compatible, zero egress costs).
* **Sync Engine**: Real-time WebSocket room hub with scheduled latency compensation and smooth drift micro-adjustments.

## Project Structure
```text
watch2gether/
├── .github/
│   └── workflows/
│       └── supabase-keepalive.yml     # GitHub Actions cron to prevent Supabase sleep
├── backend/                           # Go backend service (Scrapers, API, WebSockets)
│   ├── cmd/server/                    # Entrypoint
│   └── internal/                      # Config, Scrapers, Rooms, Database
├── frontend/                          # Flutter multiplatform application
├── docs/                              # Architecture and deployment specifications
├── .gitignore                         # Project gitignore (excludes TODO.md & secrets)
├── LICENSE
└── README.md
```

## Getting Started

### Prerequisites
* Go 1.22+
* Flutter 3.44+
* Supabase project credentials

### Development
1. **Backend**:
   ```bash
   cd backend
   go run cmd/server/main.go
   ```
2. **Frontend**:
   ```bash
   cd frontend
   flutter run -d windows
   ```
