# ADR 0008: Docker Compose for Local Environments

## Status
Accepted

## Context
Developers need a local environment that:
- Runs the full stack (PostgreSQL, Serverpod backend, Flutter frontend)
- Matches production contracts and behavior
- Starts with one command
- Isolates dependencies (no host PostgreSQL/Dart/Flutter required)
- Supports hot reload for backend and frontend
- Runs on Linux, macOS, Windows (WSL2)

## Decision
**Docker Compose** orchestrates the local development stack.

## Architecture

```
docker/
├── compose.yaml              # Main stack
├── compose.override.yaml     # Developer overrides (gitignored)
├── Dockerfile.server         # Serverpod backend
├── Dockerfile.client         # Flutter Web (dev server)
├── Dockerfile.worker-base    # Base worker image
├── Dockerfile.worker-linux   # Linux worker (docker, flutter, etc.)
├── Dockerfile.worker-macos   # macOS worker (xcode, flutter) - CI only
└── postgres/
    └── init.sql              # Extensions, initial schema
```

### Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| `postgres` | `postgres:16` | 5432 | Primary database |
| `server` | `shipit/server:dev` | 8080 | Serverpod backend |
| `client` | `shipit/client:dev` | 8081 | Flutter Web dev server |
| `worker-linux` | `shipit/worker-linux:dev` | - | Linux worker pool |
| `worker-mock` | `shipit/worker-mock:dev` | - | Mock worker for testing |

### compose.yaml (Core)

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: shipit
      POSTGRES_USER: shipit
      POSTGRES_PASSWORD: shipit
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U shipit"]
      interval: 5s
      timeout: 5s
      retries: 5

  server:
    build:
      context: ../control_plane/server
      dockerfile: ../../docker/Dockerfile.server
    environment:
      SERVERPOD_DATABASE_HOST: postgres
      SERVERPOD_DATABASE_NAME: shipit
      SERVERPOD_DATABASE_USER: shipit
      SERVERPOD_DATABASE_PASSWORD: shipit
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ../control_plane/server:/app
      - /app/.dart_tool  # Cache isolation

  client:
    build:
      context: ../control_plane/client
      dockerfile: ../../docker/Dockerfile.client
    ports:
      - "8081:8081"
    environment:
      SERVERPOD_CLIENT_ORIGIN: http://localhost:8081
      SERVERPOD_API_URL: http://server:8080
    volumes:
      - ../control_plane/client:/app
      - /app/.dart_tool

  worker-linux:
    build:
      context: ../tooling/workers
      dockerfile: ../../docker/Dockerfile.worker-linux
    environment:
      WORKER_POOL: linux
      SERVERPOD_API_URL: http://server:8080
    deploy:
      replicas: 2
    depends_on:
      - server

volumes:
  postgres_data:
```

### Developer Override (compose.override.yaml.example)

```yaml
# Copy to compose.override.yaml and customize
services:
  server:
    environment:
      - LOG_LEVEL=debug
    # Mount local Dart SDK for faster rebuilds
    # volumes:
    #   - ~/.pub-cache:/root/.pub-cache

  client:
    environment:
      - FLUTTER_WEB_RENDERER=html
```

## Hot Reload

- **Server**: `dart run --hot-reload` via Serverpod CLI (volume-mounted source)
- **Client**: `flutter run -d web-server --web-port 8081` (volume-mounted source)
- **Packages**: `melos bootstrap` in each container, or mount `packages/` volume

## Worker Images

```
Dockerfile.worker-base:
  FROM ubuntu:24.04
  # Common: git, curl, jq, docker CLI, gcloud CLI
  
Dockerfile.worker-linux:
  FROM worker-base
  # flutter, android-sdk, node, python, opencode
  
Dockerfile.worker-macos:
  # NOT in Docker Compose (macOS containers not portable)
  # Defined here for CI (GitHub Actions macOS runners)
```

## Consequences

### Positive
- Single command: `cd docker && docker compose up -d`
- Identical PostgreSQL version locally and in prod
- No host toolchain required (Dart, Flutter, PostgreSQL in containers)
- Worker images test capability matrix locally
- Compose override for personal customization

### Negative
- Docker Desktop resource usage (RAM/CPU)
- macOS workers can't run in Docker Compose (CI only)
- Volume mount performance on macOS/Windows
- Image rebuilds needed for dependency changes

### Mitigation
- Document resource requirements (8GB+ RAM recommended)
- Use `docker compose watch` for auto-rebuild on Dockerfile changes
- Provide `make dev` wrapper for common commands
- CI uses same Dockerfiles for consistency