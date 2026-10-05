# E2E Integration Environment

This document describes the E2E (End-to-End) integration test environment for SHIP IT. This environment is designed for automated testing in CI/CD pipelines and mirrors production-like conditions.

## Quick Start

### Using Make (Recommended)

```bash
# Run E2E tests (builds, starts stack, runs tests, tears down)
make e2e-test

# View test results
make e2e-logs
```

### Using Docker Compose Directly

```bash
# Run E2E tests (builds, starts stack, runs tests, tears down)
docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit --exit-code-from test-runner

# View test results
docker compose -f docker/compose.e2e.yaml logs test-runner
```

## Makefile Commands

```bash
make e2e-up         # Start E2E stack
make e2e-down       # Stop and remove E2E stack
make e2e-test       # Run E2E tests (full cycle)
make e2e-logs       # Follow test runner logs
```

## Prerequisites

- Docker Engine 24+
- Docker Compose v2+
- 6GB+ available RAM
- No port publishing (services communicate internally)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    E2E Integration Network                       │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Test Runner │───▶│   Client    │───▶│   Server    │         │
│  │  (Playwright)│    │  (nginx)    │    │   :8080     │         │
│  └─────────────┘    └──────┬──────┘    └──────┬──────┘         │
│                            │                   │                │
│                     ┌──────▼──────┐    ┌──────▼──────┐         │
│                     │ PostgreSQL  │    │ Triage Repo │         │
│                     │  (tmpfs)    │    │  (volume)   │         │
│                     └─────────────┘    └─────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Description |
|---------|-------------|
| postgres | PostgreSQL database (ephemeral, tmpfs) |
| triage-seed | Seeds a scratch git repository for triage |
| server | Serverpod backend API |
| client | Flutter web app served by nginx |
| test-runner | Playwright/Cypress test execution |

## Key Differences from Local QA

| Aspect | Local QA | E2E Integration |
|--------|----------|-----------------|
| Database | Persistent volume (`postgres_data_qa`) | Ephemeral tmpfs |
| Ports | Published to host (5432, 8080, 8081) | Internal only |
| Client URL | `http://localhost:8081` | `http://client:8081` (internal) |
| API URL | `http://localhost:8081/api/` | `http://client:8081/api/` |
| Test Runner | Manual (browser) | Automated (Playwright) |
| Cleanup | `down -v` (manual) | `--abort-on-container-exit` (auto) |
| Lifecycle | Long-running | Single-shot per test run |

## Configuration

### Environment Variables

```bash
# Test runner configuration
TEST_TARGET_URL=http://client:8081
CONTROL_PLANE_API=http://client:8081/api/

# Client runtime config (injected via compose)
CONTROL_PLANE_API=http://client:8081/api/
API_UPSTREAM=server:8080
```

### Resource Limits

Recommended for CI runners:

```yaml
# In compose.e2e.yaml or CI config
services:
  server:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
        reservations:
          memory: 1G
          cpus: '1'
  client:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
  test-runner:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
```

## Running Tests

### Local Execution

```bash
# Full test run with cleanup
docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit --exit-code-from test-runner

# Keep containers for debugging on failure
docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit
# Then manually: docker compose -f docker/compose.e2e.yaml down -v
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Run E2E Tests
  run: |
    docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit --exit-code-from test-runner
    
- name: Upload Test Artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: e2e-test-results
    path: |
      test-results/
      playwright-report/
```

### Test Artifacts

The test runner exports artifacts to `/app/test-results/` and `/app/playwright-report/`. Mount these volumes to persist:

```yaml
services:
  test-runner:
    volumes:
      - ./test-results:/app/test-results
      - ./playwright-report:/app/playwright-report
```

## Test Runner Details

The test runner image (`Dockerfile.test-runner`) includes:
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
docker compose -f docker/compose.e2e.yaml up --build

# In another terminal, access test-runner
docker compose -f docker/compose.e2e.yaml exec test-runner sh

# Check client/server logs
docker compose -f docker/compose.e2e.yaml logs client
docker compose -f docker/compose.e2e.yaml logs server

# Manual test run inside container
docker compose -f docker/compose.e2e.yaml exec test-runner cd /app/apps/control_plane && npx playwright test --headed
```

## Common Issues

### Tests Timeout

Increase health check retries or timeout in `run-e2e-tests.sh`:
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

### Resource Exhaustion

Add resource limits (see Configuration > Resource Limits above).

## File Structure

```
docker/
├── compose.e2e.yaml         # This environment
├── compose.qa.yaml          # Local QA environment
├── Dockerfile.client        # Client image
├── Dockerfile.server        # Server image
├── Dockerfile.test-runner   # Test runner image
├── run-e2e-tests.sh         # Test runner entrypoint
├── nginx.conf.template      # Nginx template
├── config.js.template       # Client config template
└── entrypoint.client.sh     # Runtime substitution
```

## Related Documentation

- [Local QA Environment](./local-qa.md)
- [Architecture Decision: Local Deployment](../engineering/adr/001-local-deployment.md)
- [Architecture Decision: Environment Separation](../engineering/adr/002-environment-separation.md)