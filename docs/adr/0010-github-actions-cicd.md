# ADR 0010: GitHub Actions as CI/CD Execution Engine

## Status
Accepted

## Context
Need CI/CD for:
- Dart package analysis, formatting, tests
- Serverpod backend build, test, Docker image
- Flutter Web build, test, Docker image
- Worker image builds
- OpenTofu plan/apply
- Integration tests (full stack)
- Release artifact promotion

Constraints:
- No custom CI engine (per principles)
- Must run on Linux and macOS (for iOS/macOS workers)
- Must support Docker layer caching
- Must integrate with GitHub (PR checks, environments)
- Self-hosted runners for macOS/iOS

## Decision
**GitHub Actions** is the CI/CD execution engine.

## Workflow Structure

```
.github/workflows/
├── ci.yaml              # PR validation (fast)
├── integration.yaml     # Full stack integration (nightly/on-demand)
├── release.yaml         # Tag-based release
├── infrastructure.yaml  # OpenTofu plan/apply
└── worker-images.yaml   # Docker image builds
```

### ci.yaml (PR Validation)

```yaml
name: CI
on: [pull_request, push]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: melos bootstrap
      - run: melos run analyze
      - run: melos run format

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: melos bootstrap
      - run: melos run test
  
  server-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          context: ./apps/server
          file: ./docker/Dockerfile.server
          push: false
          load: true
          tags: shipit/server:pr-${{ github.event.number }}
  
  client-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          context: ./packages/control_plane_client
          file: ./docker/Dockerfile.client
          push: false
          load: true
          tags: shipit/client:pr-${{ github.event.number }}
  
  opentofu-fmt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
      - run: tofu fmt -check -recursive ./infrastructure
```

### integration.yaml (Full Stack)

```yaml
name: Integration
on:
  workflow_dispatch:
  schedule: [cron: '0 2 * * *']  # Nightly
jobs:
  full-stack:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: shipit_test
          POSTGRES_USER: shipit
          POSTGRES_PASSWORD: shipit
        ports: [5432:5432]
        options: >-
          --health-cmd "pg_isready -U shipit"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - name: Start stack
        run: |
          cd docker
          docker compose up -d
          # Wait for health checks
          sleep 30
      - name: Run integration tests
        run: |
          cd apps/server
          dart test integration_test/
      - name: Teardown
        if: always()
        run: cd docker && docker compose down -v
```

### release.yaml

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: ./apps/server
          file: ./docker/Dockerfile.server
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/server:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}/server:latest
      - uses: docker/build-push-action@v5
        with:
          context: ./packages/control_plane_client
          file: ./docker/Dockerfile.client
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/client:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}/client:latest
  
  worker-images:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          context: ./tooling/workers
          file: ./docker/Dockerfile.worker-linux
          push: true
          tags: ghcr.io/${{ github.repository }}/worker-linux:${{ github.ref_name }}
  
  infrastructure:
    needs: [build-and-push, worker-images]
    uses: ./.github/workflows/infrastructure.yaml
    secrets: inherit
    with:
      env: production
```

### macOS/iOS Workers (Self-Hosted)

```yaml
# .github/workflows/macos-workers.yaml
name: macOS Workers
on: [push, pull_request]
jobs:
  build-worker-macos:
    runs-on: [self-hosted, macos, arm64]  # MacStadium / GitHub macOS runners
    steps:
      - uses: actions/checkout@v4
      - name: Build macOS worker image (pkg/dmg)
        run: |
          cd tooling/workers
          ./build_macos_worker.sh
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: worker-macos
          path: dist/worker-macos-*.pkg
  
  test-ios:
    runs-on: [self-hosted, macos, arm64]
    steps:
      - uses: actions/checkout@v4
      - name: Run iOS tests
        run: |
          cd packages/control_plane_client
          flutter test integration_test/ios_test.dart
```

## Consequences

### Positive
- Native GitHub integration (PR checks, environments, secrets)
- Linux + macOS runners (GitHub-hosted + self-hosted)
- Docker layer caching via `actions/cache`
- Reusable workflows for common patterns
- No separate CI infrastructure to manage

### Negative
- GitHub Actions minutes cost at scale
- Self-hosted macOS runners require maintenance
- YAML complexity for complex pipelines
- Vendor lock-in to GitHub

### Mitigation
- Use `act` for local workflow testing
- Optimize caching (Dart pub cache, Docker layers)
- Document self-hosted runner setup
- Evaluate migration path if needed (but not premature)