# Test Environment

This document describes the isolated test environment for SHIP IT. This environment is completely separate from the local QA environment and is designed for automated testing and CI/CD pipelines.

## Quick Start

```bash
# Start test environment
make test-env-up

# Run tests against test environment
make test-env-test

# Stop and clean up
make test-env-down
```

## Prerequisites

- Docker Engine 24+
- Docker Compose v2+
- 4GB+ available RAM
- Ports 5433, 8082, 8083 available (different from QA environment)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Test Environment Network                      │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Test Runner │───▶│   Client    │───▶│   Server    │         │
│  │  (Playwright)│    │  (nginx)    │    │   :8080     │         │
│  └─────────────┘    └──────┬──────┘    └──────┬──────┘         │
│                            │                   │                │
│                     ┌──────▼──────┐    ┌──────▼──────┐         │
│                     │ PostgreSQL  │    │ Triage Repo │         │
│                     │  :5433 (tmpfs)    │  (volume)   │         │
│                     └─────────────┘    └─────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Differences from Local QA

| Aspect | Local QA | Test Environment |
|--------|----------|-----------------|
| Database | Persistent volume | Ephemeral tmpfs |
| Ports | 5432, 8080, 8081 | 5433, 8082, 8083 |
| Client URL | `http://localhost:8081` | `http://localhost:8083` |
| Server URL | `http://localhost:8080` | `http://localhost:8082` |
| API URL | `http://localhost:8081/api/` | `http://localhost:8083/api/` |
| Cleanup | `down -v` (manual) | `--abort-on-container-exit` (auto) |
| Lifecycle | Long-running | Single-shot per test run |

## Services

| Service | Port | Description |
|---------|------|-------------|
| postgres | 5433 | PostgreSQL database (ephemeral, tmpfs) |
| triage-seed | - | Seeds a scratch git repository for triage |
| server | 8082 | Serverpod backend API |
| client | 8083 | Flutter web app served by nginx |

## Configuration

### Environment Variables

```bash
# Test environment uses different ports to avoid conflicts with QA
PORT_OFFSET=1000

# Database (ephemeral)
POSTGRES_DB=shipit_test
POSTGRES_USER=shipit
POSTGRES_PASSWORD=shipit

# Server
SERVERPOD_API_SERVER_PORT=8080
SHIPIT_TRIAGE_REPOSITORY_PATH=/triage-repo
SHIPIT_TRIAGE_WORKSPACE_ROOT=/triage-workspaces

# Client runtime config
CONTROL_PLANE_API=http://localhost:8083/api/
API_UPSTREAM=server:8080
```

## Running Tests

### Local Execution

```bash
# Full test run with cleanup
docker compose -f docker/compose.test.yaml up --build --abort-on-container-exit --exit-code-from test-runner

# Keep containers for debugging on failure
docker compose -f docker/compose.test.yaml up --build --abort-on-container-exit
# Then manually: docker compose -f docker/compose.test.yaml down -v
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Run E2E Tests
  run: |
    make test-env-up
    # Wait for services to be ready
    sleep 10
    make test-env-test
    
- name: Upload Test Artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: test-results/
```

### Makefile Commands

```bash
make test-env-up      # Build and start test environment
make test-env-down    # Stop and remove test environment
make test-env-test    # Run E2E tests against test environment
make test-env-logs    # View test environment logs
make test-env-ps      # Show test environment status
```

## Test Runner Details

The test runner image includes:
- Node.js 20 + Playwright 1.44
- Chromium browser
- Flutter 3.44 (for Dart-based tests)
- Bash, curl for health checks

### Health Checks

Before running tests, the runner waits for:
1. Client HTTP endpoint (`/`) - 30 attempts × 2s
2. Server API health endpoint (`/api/health`) - 30 attempts × 2s

### Test Execution

The runner looks for tests in this order:
1. Dart E2E tests: `apps/control_plane/test/e2e/e2e_test.dart` (via `flutter test`)
2. Node.js Playwright tests: `package.json` with `playwright` dependency (via `npx playwright test`)

If neither exists, it exits 0 with a warning (allows pipeline to pass while tests are being developed).

## Debugging Failed Tests

```bash
# Run without auto-exit to inspect
docker compose -f docker/compose.test.yaml up --build

# In another terminal, access test-runner
docker compose -f docker/compose.test.yaml exec test-runner sh

# Check client/server logs
docker compose -f docker/compose.test.yaml logs client
docker compose -f docker/compose.test.yaml logs server

# Manual test run inside container
docker compose -f docker/compose.test.yaml exec test-runner cd /app/apps/control_plane && npx playwright test --headed
```

## Common Issues

### Tests Timeout

Increase health check retries or timeout in `docker/run-e2e-tests.sh`:
```bash
for i in {1..60}; do  # Increase from 30
```

### Database Migration Failures

Ensure migrations are idempotent. The server runs `--apply-migrations` on startup against a fresh database.

### Flaky Tests

The runner supports retry logic. Configure in Playwright:
```typescript
// playwright.config.ts
retries: 2,
```

### Port Conflicts

If ports 5433, 8082, or 8083 are in use:
```bash
# Check what's using the ports
lsof -i :5433 -i :8082 -i :8083
```

## File Structure

```
docker/
├── compose.test.yaml         # This environment
├── compose.qa.yaml           # Local QA environment
├── compose.e2e.yaml          # Legacy E2E environment
├── Dockerfile.client         # Client image
├── Dockerfile.server         # Server image
├── Dockerfile.test-runner    # Test runner image
├── run-e2e-tests.sh          # Test runner entrypoint
├── nginx.conf.template       # Nginx template
├── config.js.template        # Client config template
└── entrypoint.client.sh      # Runtime substitution
```

## Related Documentation

- [Local QA Environment](./local-qa.md)
- [E2E Integration Environment](./e2e-integration.md)
- [Architecture Decision: Local Deployment](../engineering/adr/001-local-deployment.md)
- [Architecture Decision: Environment Separation](../engineering/adr/002-environment-separation.md)