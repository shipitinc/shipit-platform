# Local QA Environment

This document describes how to run the SHIP IT Control Plane locally for manual QA, debugging, and development iteration.

## Quick Start

### Using Make (Recommended)

```bash
# Start the full stack (builds client, starts all services)
make qa-up

# Access the UI at http://localhost:8081
# API available at http://localhost:8081/api/

# Stop and clean up
make qa-down
```

### Using Docker Compose Directly

```bash
# Build client image first (required - runs Flutter build locally)
./docker/build-client.sh

# Start the full stack
docker compose -f docker/compose.qa.yaml up -d

# Access the UI at http://localhost:8081
# API available at http://localhost:8081/api/

# Stop and clean up
docker compose -f docker/compose.qa.yaml down -v
```

### Why build client locally?

The Flutter web SDK downloads from `storage.googleapis.com` during `flutter build web`. Cloudflare WARP and some corporate VPNs block this. The `build-client.sh` script runs the Flutter build on your host machine (where WARP doesn't interfere) then copies artifacts into the Docker image.

## Prerequisites

- Docker Engine 24+
- Docker Compose v2+
- 4GB+ available RAM
- Ports 5432, 8080, 8081 available

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host Machine                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   Browser    │───▶│   Client     │───▶│    Server    │   │
│  │  :8081       │    │  (nginx)     │    │   :8080      │   │
│  └──────────────┘    └──────┬───────┘    └──────┬───────┘   │
│                             │                   │            │
│                      ┌──────▼───────┐    ┌──────▼───────┐   │
│                      │  PostgreSQL  │    │ Triage Repo  │   │
│                      │   :5432      │    │   (volume)   │   │
│                      └──────────────┘    └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| postgres | 5432 | PostgreSQL database (persistent volume) |
| triage-seed | - | Seeds a scratch git repository for triage |
| server | 8080 | Serverpod backend API |
| client | 8081 | Flutter web app served by nginx |

## Configuration

### Environment Variables

Create a `.env` file in the repository root (not committed):

```bash
# Optional: Offset all published ports to avoid conflicts
PORT_OFFSET=0

# Database (defaults shown)
POSTGRES_DB=shipit
POSTGRES_USER=shipit
POSTGRES_PASSWORD=shipit

# Server (defaults shown)
SERVERPOD_API_SERVER_PORT=8080
```

### Client Runtime Configuration

The client container accepts these environment variables at **runtime** (not build time):

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTROL_PLANE_API` | `http://localhost:8081/api/` | Base URL for API calls from the browser |
| `API_UPSTREAM` | `server:8080` | Upstream target for nginx `/api/` proxy |

These are substituted into:
- `/usr/share/nginx/html/config.js` (read by Flutter app via `window.SHIPIT_CONFIG`)
- `/etc/nginx/conf.d/default.conf` (nginx proxy_pass target)

### Standalone Client Mode

Run the client against an external backend (e.g., server running on host):

```bash
docker run -d \
  -p 8081:8081 \
  -e CONTROL_PLANE_API=http://host.docker.internal:8080/api/ \
  -e API_UPSTREAM=host.docker.internal:8080 \
  shipit-client:latest
```

## Development Workflows

### Full Stack Development

```bash
# Start everything
docker compose -f docker/compose.qa.yaml up --build

# View logs
docker compose -f docker/compose.qa.yaml logs -f server
docker compose -f docker/compose.qa.yaml logs -f client

# Restart single service
docker compose -f docker/compose.qa.yaml restart server
```

### Client-Only Development (Hot Reload)

For fast UI iteration with hot reload:

```bash
# 1. Start backend only
docker compose -f docker/compose.qa.yaml up -d postgres triage-seed server

# 2. Run Flutter dev server (in separate terminal)
cd apps/control_plane
flutter run -d web-server --web-port 8081 \
  --dart-define=CONTROL_PLANE_API=http://localhost:8081/api/

# 3. Access http://localhost:8081 in browser
# 4. Edit Dart code → hot reload
```

The Flutter dev server proxies `/api/` to `http://localhost:8080` via its proxy configuration.

### Backend-Only Development

```bash
# Start only database and server
docker compose -f docker/compose.qa.yaml up -d postgres triage-seed server

# Server logs
docker compose -f docker/compose.qa.yaml logs -f server
```

## Makefile Commands (Recommended)

All common operations are available via `make`:

```bash
# QA Environment
make qa-up          # Build + start full stack
make qa-down        # Stop + remove (with volumes)
make qa-logs        # Follow logs
make qa-ps          # Show service status
make qa-restart     # Restart services
make qa-build       # Build all images
make qa-build-client # Build client image (includes Flutter build)

# E2E Environment
make e2e-up         # Start E2E stack
make e2e-down       # Stop E2E stack
make e2e-test       # Run E2E tests

# Client Development
make client-dev     # Start backend + run Flutter dev server

# Cleanup
make clean          # Remove everything
```

See `Makefile` for all targets.

## Common Operations

### Reset Database

```bash
make qa-down
make qa-up
```

### Rebuild Client Only

```bash
# Using Make (includes Flutter build)
make qa-build-client

# Or using Docker directly
./docker/build-client.sh
docker compose -f docker/compose.qa.yaml up -d client
```

### Access Database

```bash
docker compose -f docker/compose.qa.yaml exec postgres psql -U shipit -d shipit
```

### Access Server Shell

```bash
docker compose -f docker/compose.qa.yaml exec server sh
```

### Worker Profile (opencode)

```bash
# Start worker container for opencode sessions
docker compose -f docker/compose.qa.yaml --profile workers up -d worker-linux
```

## Troubleshooting

### Port Conflicts

If ports 5432, 8080, or 8081 are in use:

```bash
# Option 1: Use PORT_OFFSET
PORT_OFFSET=1000 docker compose -f docker/compose.qa.yaml up
# Maps to 15432, 10880, 10881

# Option 2: Stop conflicting services
# Check what's using the ports
lsof -i :5432 -i :8080 -i :8081
```

### Container Won't Start

```bash
# Check logs
docker compose -f docker/compose.qa.yaml logs <service-name>

# Common issues:
# - Database not healthy: check postgres logs
# - Triage seed failed: check triage-seed logs
# - Server migration failed: check server logs
```

### Client Can't Reach API

1. Verify `CONTROL_PLANE_API` in browser DevTools: `window.SHIPIT_CONFIG`
2. Check nginx config: `docker compose -f docker/compose.qa.yaml exec client cat /etc/nginx/conf.d/default.conf`
3. Verify server is healthy: `curl http://localhost:8080/health`
4. Check nginx error logs: `docker compose -f docker/compose.qa.yaml logs client`

### Triage Repository Issues

```bash
# Check triage repo
docker compose -f docker/compose.qa.yaml exec server ls -la /triage-repo

# Re-seed if needed
docker compose -f docker/compose.qa.yaml rm -f triage-seed
docker compose -f docker/compose.qa.yaml up triage-seed
```

## File Structure

```
docker/
├── compose.qa.yaml          # This environment
├── compose.e2e.yaml         # E2E integration environment
├── Dockerfile.client        # Client image with runtime config
├── Dockerfile.server        # Server image
├── Dockerfile.test-runner   # E2E test runner
├── nginx.conf.template      # Nginx template with envsubst
├── config.js.template       # Client runtime config template
└── entrypoint.client.sh     # Runtime substitution script
```

## Related Documentation

- [E2E Integration Environment](./e2e-integration.md)
- [Architecture Decision: Local Deployment](../engineering/adr/001-local-deployment.md) (to be created)
- [Architecture Decision: Environment Separation](../engineering/adr/002-environment-separation.md) (to be created)