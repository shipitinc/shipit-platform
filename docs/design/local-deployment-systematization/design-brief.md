# Design Brief: Local Deployment Systematization

**brief_id**: `9B40FC6F-DAC4-4869-A44D-A212D0A4D069`
**version**: `1.0.0`
**status**: `FROZEN`
**requirements_refs**: [`REQ-LOCAL-DEPLOY-001`, `REQ-LOCAL-DEPLOY-002`, `REQ-LOCAL-DEPLOY-003`]
**architecture_refs**: [`ADR-001-Local-Deployment`, `ADR-002-Environment-Separation`]
**created_by**: `design-agent`
**created_at**: `2026-10-04T00:00:00Z`

---

## Problem Statement

The current local deployment setup for SHIP IT has several critical issues that cause recurring friction:

1. **Hardcoded API endpoint**: The client container bakes `CONTROL_PLANE_API=http://localhost:8081/api/` at build time via `--dart-define`. This only works when the client and server share the same Docker Compose network (where `localhost:8081` routes through nginx to the `server` service). When running the client standalone (e.g., for manual QA), the API calls fail because `localhost:8081` doesn't proxy to anything.

2. **Nginx proxy hostname resolution**: The nginx configuration in the client container uses `proxy_pass http://server:8080/;` which relies on Docker Compose's internal DNS. This hostname (`server`) does not resolve outside the compose network, making standalone client operation impossible.

3. **No environment separation**: There is no clear distinction between:
   - **Local QA Environment**: Developer-run environment for manual testing, debugging, and iteration. Should be fast to start, easy to reset, and support hot-reload where possible.
   - **E2E Integration Environment**: Automated test environment that mirrors production-like conditions for CI/CD pipelines. Should be deterministic, isolated, and disposable.

4. **Production deployment in workflow**: The current orchestration workflow (WORKFLOW.md steps 32-38, cloudbuild.yaml, cloudbuild.release.yaml) includes staging and production deployment gates. Per the requirement, production deployment should be removed from the workflow entirely — only local QA deployment (rebuilding the Docker instance) should remain.

5. **Rediscovery overhead**: Developers must repeatedly figure out how to run the stack locally because there's no documented, systematized approach that separates concerns cleanly.

---

## User Flows

### Flow 1: Local QA Environment — Developer Manual Testing

**Entry Criteria**: Developer has cloned the repository, has Docker/Docker Compose installed, wants to manually test the control plane UI against a local backend.

**Steps**:
1. Developer runs `docker compose -f docker/compose.qa.yaml up --build`
2. System starts: PostgreSQL, triage-seed, server (port 8080), client (port 8081)
3. Client is configured at **runtime** (not build-time) to point at `http://localhost:8081/api/` which proxies to `server:8080` within the compose network
4. Developer accesses `http://localhost:8081` in browser
5. Developer can modify client code, rebuild client image, and restart only the client service for iteration
6. Developer can stop/start individual services without full stack restart
7. On completion, `docker compose -f docker/compose.qa.yaml down -v` cleanly tears down everything

**Exit Criteria**: Developer has a working local stack for manual QA with clear separation of concerns and runtime configurability.

**Error Scenarios**:
- Port conflicts (8080, 8081, 5432) → Clear error message with resolution hints
- Database migration failures → Logs visible, `docker compose logs server` actionable
- Triage repository not seeded → Automatic retry with backoff

---

### Flow 2: E2E Integration Environment — Automated Testing

**Entry Criteria**: CI/CD pipeline or developer running integration test suite needs a production-like environment.

**Steps**:
1. System runs `docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit`
2. System starts: PostgreSQL (ephemeral), triage-seed, server (port 8080), client (port 8081), test runner
3. Client built with **production-like configuration**: API base URL injected at runtime via environment variable
4. Test runner executes Playwright/Cypress tests against `http://client:8081` (internal) or `http://localhost:8081` (host)
5. On test completion, `docker compose -f docker/compose.e2e.yaml down -v` tears down completely
6. Test results and artifacts exported to host

**Exit Criteria**: Deterministic, isolated test run with production-like networking and configuration.

**Error Scenarios**:
- Test failures → Exit code non-zero, logs preserved for CI artifact upload
- Flaky test detection → Retry logic with clear reporting
- Resource exhaustion → Memory/CPU limits enforced per service

---

### Flow 3: Local QA — Standalone Client Development (Hot Reload)

**Entry Criteria**: Developer working on client UI only, wants fast iteration with hot reload against a running backend.

**Steps**:
1. Developer starts backend stack: `docker compose -f docker/compose.qa.yaml up -d postgres triage-seed server`
2. Developer runs Flutter web dev server locally: `cd apps/control_plane && flutter run -d web-server --web-port 8081 --dart-define=CONTROL_PLANE_API=http://localhost:8081/api/`
3. Flutter dev server proxies `/api/` to `http://localhost:8080` (configured via `web-server` proxy config)
4. Developer edits Dart code → hot reload in browser
5. Backend changes: restart server container only

**Exit Criteria**: Sub-second UI iteration cycle with live backend.

---

## Success Criteria

| ID | Criterion | Measurement |
|----|-----------|-------------|
| SC-01 | Client API endpoint configurable at **runtime** (not build-time) | `CONTROL_PLANE_API` injected via environment variable or config file, no `--dart-define` at build |
| SC-02 | Nginx proxy resolves backend via configurable hostname | `proxy_pass` target configurable via environment variable (e.g., `API_UPSTREAM`) |
| SC-03 | Two distinct compose files: `compose.qa.yaml` and `compose.e2e.yaml` | Files exist, documented, used in respective flows |
| SC-04 | Local QA stack starts in < 60 seconds (cold) / < 10 seconds (warm) | Measured on M-series Mac / Linux CI runner |
| SC-05 | E2E stack starts and runs tests in < 180 seconds | Measured in CI |
| SC-06 | Production deployment removed from WORKFLOW.md and CI configs | `cloudbuild.release.yaml` archived/removed; WORKFLOW.md steps 32-38 modified/removed |
| SC-07 | Documentation for both flows in `docs/deployment/local-qa.md` and `docs/deployment/e2e-integration.md` | Files exist, accurate, tested |
| SC-08 | No hardcoded `localhost` or `server` hostnames in built images | All networking configurable at container start |
| SC-09 | Client can run standalone (without server in same compose) when API URL provided | Verified by running client container with `CONTROL_PLANE_API=http://host.docker.internal:8080/api/` |

---

## Constraints

| ID | Constraint | Type | Notes |
|----|------------|------|-------|
| C-01 | Must use existing Docker/Compose infrastructure | Technical | No new orchestration tools (k8s, tilt, etc.) |
| C-02 | Serverpod configuration (`config/development.yaml`) must not be forked | Technical | Port 8080 via `SERVERPOD_API_SERVER_PORT` env var is acceptable |
| C-03 | Client is a prebuilt static site served by nginx | Technical | Runtime config via nginx `envsubst` or similar mechanism |
| C-04 | Triage repository seeding must remain functional | Technical | Volume mounts and init logic preserved |
| C-05 | Worker-linux profile (opencode container) must remain available | Technical | `docker compose --profile workers` still works |
| C-06 | No production credentials in local configs | Security | `.env` for local only, never committed |
| C-07 | Database persistence optional for QA, ephemeral for E2E | Operational | QA: named volume; E2E: tmpfs or no volume |
| C-08 | Must support Apple Silicon (arm64) and AMD64 | Platform | Base images multi-arch |
| C-09 | Flutter version pinned via `.fvmrc` / `cirrusci/flutter:3.44.0` | Technical | No version drift |

---

## Acceptance Criteria

| ID | Acceptance Criterion | Traceability |
|----|---------------------|--------------|
| AC-01 | `docker compose -f docker/compose.qa.yaml up --build` starts full stack successfully | SC-01, SC-02, SC-03, SC-04 |
| AC-02 | Client at `http://localhost:8081` loads and communicates with server via `/api/` proxy | SC-01, SC-02 |
| AC-03 | `CONTROL_PLANE_API` configurable via environment variable at container start | SC-01 |
| AC-04 | Nginx `proxy_pass` target configurable via `API_UPSTREAM` environment variable | SC-02 |
| AC-05 | `docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit` runs test suite | SC-03, SC-05 |
| AC-06 | Production deployment steps removed from WORKFLOW.md (steps 32-38) | SC-06 |
| AC-07 | `cloudbuild.release.yaml` archived to `cloudbuild.release.yaml.archive` or removed | SC-06 |
| AC-08 | `cloudbuild.yaml` modified to only build/push images (no deploy steps) | SC-06 |
| AC-09 | Documentation created for both environments | SC-07 |
| AC-10 | Client container runs standalone with `docker run -e CONTROL_PLANE_API=... -e API_UPSTREAM=...` | SC-08, SC-09 |
| AC-11 | Worker-linux profile still functional in both compose files | C-05 |

---

## Risk Assessment

| Risk | Level (0-3) | Rationale | Mitigation |
|------|-------------|-----------|------------|
| Runtime configuration mechanism fails for Flutter web (dart-define is compile-time) | 2 | Flutter web compiles `String.fromEnvironment` at build time; runtime injection requires `index.html` templating or config JSON fetch | Use nginx `envsubst` on a generated `config.js` fetched at runtime, or build-time argument with compose variable substitution |
| Nginx `envsubst` doesn't work in `nginx:alpine` base image | 1 | `envsubst` is in `gettext` package; need to install or use alternative | Install `gettext` in Dockerfile.client, or use `dockerize` template, or custom entrypoint script |
| Database migration failures in ephemeral E2E environment | 1 | `--apply-migrations` runs on server start; fresh DB each time | Ensure migrations are idempotent; healthcheck waits for DB ready |
| Port conflicts on developer machines | 1 | 8080, 8081, 5432 commonly used | Document `PORT_OFFSET` env var or alternative ports in `.env.example` |
| Removing production deployment breaks existing CI/CD expectations | 2 | Other tooling may depend on cloudbuild artifacts | Archive instead of delete; communicate change; ensure image builds still publish to artifact registry |
| Triage repository seeding race condition with server start | 1 | `depends_on: condition: service_completed_successfully` should handle | Verify healthcheck ordering; add retry logic in server entrypoint |
| Hot reload flow (Flow 3) requires Flutter dev server proxy config | 1 | `flutter run -d web-server` supports `--proxy-config` | Document proxy config file in `apps/control_plane/web_proxy.yaml` |

**Overall Risk Level**: **1** (Design-System Correction — primarily configuration/infrastructure changes, no user-facing UX changes)

**Risk Rationale**: This design addresses infrastructure/configuration concerns only. No user flows, UI components, navigation, or information architecture are changed. The risk is limited to developer experience and CI/CD reliability. Per DESIGN_GOVERNANCE.md, this classifies as **Level 1** (Design-System Correction) — requires design-system owner notification but no human gate unless objected.

---

## Traceability Matrix

| Requirement | Design Brief Section | Covered |
|-------------|---------------------|---------|
| REQ-LOCAL-DEPLOY-001: Separate QA and E2E environments | User Flows 1 & 2, Success Criteria SC-03 | ✅ |
| REQ-LOCAL-DEPLOY-002: Runtime-configurable API endpoint | Problem Statement, SC-01, AC-03 | ✅ |
| REQ-LOCAL-DEPLOY-003: Remove production deployment from workflow | Problem Statement, SC-06, AC-06, AC-07, AC-08 | ✅ |
| REQ-LOCAL-DEPLOY-004: Eliminate rediscovery overhead | Problem Statement, Documentation AC-09 | ✅ |

**Requirements Gaps**: None identified at this stage.

---

## Design System Compliance

**Status**: `UNKNOWN` — This is an infrastructure/deployment design, not a UI design. Design system tokens, components, and patterns are not directly applicable. The design reviewer should assess as `N/A` or `PASS` for infrastructure concerns.

---

## UX / Accessibility Score

**Status**: `UNKNOWN` — No user-facing UI changes. Developer experience (DX) improvements only. Accessibility not applicable.

---

## Implementation Feasibility

**Rating**: `HIGH`

**Rationale**: 
- Changes are confined to Dockerfiles, nginx config, compose files, and documentation
- No application code changes required (server/client business logic untouched)
- Well-understood patterns: runtime config via `envsubst`, multi-compose files, environment variables
- Existing CI/CD builds images; only deployment steps removed
- Estimated effort: 2-3 implementation days

---