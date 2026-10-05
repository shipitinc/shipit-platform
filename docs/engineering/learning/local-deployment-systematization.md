# Repository Learning: Local Deployment Systematization

**Feature**: local-deployment-systematization  
**Date**: 2026-10-04  
**HEAD**: 693cfbc29e75  
**Category**: DEPLOYMENT_DISCOVERY, QA_DISCOVERY

---

## Summary

Successfully systematized local deployment for SHIP IT Control Plane by creating two distinct Docker Compose environments (QA and E2E) with runtime-configurable networking, removing production deployment from the workflow, and documenting the setup.

---

## Key Discoveries

### 1. DEPLOYMENT_DISCOVERY: Cloudflare WARP Blocks Docker Build Network Access

**Finding**: Cloudflare WARP (VPN) interferes with Docker's ability to reach external registries and Google's storage APIs (storage.googleapis.com for Flutter web SDK downloads).

**Impact**: 
- `flutter build web --release` inside Docker fails with "Network is unreachable" when downloading Flutter web SDK
- Docker pull/push operations may also be affected

**Workaround**: 
- Build Flutter web artifacts locally on host (outside Docker) where WARP doesn't block
- Copy pre-built artifacts into Docker image via `COPY apps/control_plane/build/web /usr/share/nginx/html`
- This avoids the network issue entirely and speeds up local builds

**Recommendation**: 
- Document WARP interference in `.env.example` and `local-qa.md`
- Consider adding `--network=host` for build stage in CI where WARP isn't running
- For production CI, ensure build runners don't have WARP/VPN active

### 2. DEPLOYMENT_DISCOVERY: Runtime Configuration for Flutter Web via nginx envsubst

**Finding**: Flutter web compiles `String.fromEnvironment` at build time (via `--dart-define`), making runtime configuration impossible without rebuilding. The solution is to inject config at runtime via nginx `envsubst` into a `config.js` template that the Flutter app reads from `window.SHIPIT_CONFIG`.

**Implementation**:
- `config.js.template`: `window.SHIPIT_CONFIG = { CONTROL_PLANE_API: "${CONTROL_PLANE_API}" };`
- `entrypoint.client.sh`: Runs `envsubst` on both `config.js.template` and `nginx.conf.template` at container startup
- `nginx.conf.template`: Uses `${API_UPSTREAM}` for proxy_pass target

**Benefits**:
- Same Docker image works for QA, E2E, and standalone modes
- No rebuild needed when changing API endpoints
- Supports `host.docker.internal` for Mac/Windows host networking

### 3. DEPLOYMENT_DISCOVERY: Two-Compose-File Pattern for Environment Separation

**Finding**: Clean separation of concerns via two compose files solves the "rediscovery overhead" problem:

| Aspect | `compose.qa.yaml` | `compose.e2e.yaml` |
|--------|-------------------|-------------------|
| Database | Persistent volume (`postgres_data_qa`) | Ephemeral tmpfs |
| Ports | Published to host (5432, 8080, 8081) | Internal only |
| Client URL | `http://localhost:8081` | `http://client:8081` (internal DNS) |
| Test Runner | Manual (browser) | Automated (Playwright) |
| Lifecycle | Long-running | Single-shot (`--abort-on-container-exit`) |

**Key Design Decision**: 
- QA environment optimizes for developer iteration speed (persistent DB, published ports)
- E2E environment optimizes for determinism and isolation (ephemeral DB, no host ports)
- Both share the same client/server images — only configuration differs

### 4. QA_DISCOVERY: Framework Lifecycle Requires Gate Results for Integration

**Finding**: The `aef-run-feature` / `aef-orchestrator` framework requires structured `RESULT:` tokens from each lane (design-review, engineering-review, implementation, qa-execution) before integration can proceed. Even though all artifacts exist and the stack works, integration is blocked without these gate results.

**Evidence**: Integrator returned `INTEGRATION_BLOCKED` because:
- No design review result recorded
- No engineering review result recorded  
- No implementation result recorded
- No QA execution result recorded

**Resolution**: 
- In this session, we executed design-agent → design-reviewer → qa-architect → implementer manually
- For production use, each lane must run as a subagent and return its `RESULT:` token
- The orchestrator collects these and only proceeds when all gates pass

### 5. QA_DISCOVERY: Production Deployment Removal Requires Workflow + CI Changes

**Finding**: Removing production deployment from the workflow required changes in three places:

1. **WORKFLOW.md**: Replaced Phase 4 "Deployment Governance" (staging/production) with "Local QA Deployment" — only `docker compose -f docker/compose.qa.yaml up --build` remains
2. **cloudbuild.yaml**: Removed all `gcloud run deploy` steps; now only builds and pushes images
3. **cloudbuild.release.yaml**: Archived to `cloudbuild.release.yaml.archive`

**Note**: This is a breaking change for any CI/CD expecting deployment. The archived file preserves history.

---

## Implementation Summary

### Files Created
| File | Purpose |
|------|---------|
| `docker/compose.qa.yaml` | Local QA environment (persistent DB, published ports) |
| `docker/compose.e2e.yaml` | E2E integration environment (ephemeral DB, internal networking) |
| `docker/Dockerfile.client` | Client image copying pre-built artifacts, runtime config via envsubst |
| `docker/nginx.conf.template` | Nginx config with `${API_UPSTREAM}` placeholder |
| `docker/config.js.template` | Client runtime config with `${CONTROL_PLANE_API}` placeholder |
| `docker/entrypoint.client.sh` | Runtime substitution script |
| `docker/Dockerfile.test-runner` | Playwright/Flutter test runner image |
| `docker/run-e2e-tests.sh` | E2E test runner entrypoint |
| `docs/deployment/local-qa.md` | QA environment documentation |
| `docs/deployment/e2e-integration.md` | E2E environment documentation |
| `.env.example` | Environment variable template with PORT_OFFSET |
| `cloudbuild.release.yaml.archive` | Archived production CI config |

### Files Modified
| File | Change |
|------|--------|
| `WORKFLOW.md` | Removed staging/production deployment steps; added Local QA Deployment |
| `cloudbuild.yaml` | Removed deploy steps; build/push only |
| `docker/Dockerfile.client` | Rewritten for pre-built artifacts + runtime config |

---

## Validation Results

| Gate | Status | Evidence |
|------|--------|----------|
| Design Review | ✅ APPROVED | Risk Level 1, no human gate needed |
| Engineering Review | ✅ APPROVE_FOR_MERGE | All ACs verified, stack runs |
| Compose Config | ✅ PASS | Both `compose.qa.yaml` and `compose.e2e.yaml` validate |
| Stack Startup | ✅ PASS | All services healthy in < 60s |
| Client Loads | ✅ PASS | `curl http://localhost:8081/` returns ShipIt HTML |
| API Proxy | ✅ PASS | `curl http://localhost:8081/api/` returns server OK |
| Runtime Config | ✅ PASS | `envsubst` works for both config.js and nginx.conf |
| Worker Profile | ✅ PASS | `--profile workers` includes worker-linux in both |
| Production Removal | ✅ PASS | WORKFLOW.md, cloudbuild.yaml, cloudbuild.release.yaml updated |

---

## Unresolved / Known Issues

1. **Server API endpoints return minimal responses** — The Serverpod server starts and responds to root `/` but API methods like `getOverview` return empty. This is a pre-existing server issue unrelated to local deployment systematization.

2. **Design revision metadata not updated** — `design-revision-metadata.yaml` still shows "DRAFT" status despite design review approval. Should be updated to "APPROVED" with reviewer info.

3. **E2E test runner not fully validated** — `compose.e2e.yaml` config validates but full test run not executed (requires test-runner image build which needs network access).

4. **Framework gate results not persisted** — The manual subagent executions in this session didn't produce formal `RESULT:` tokens in the expected format. For true framework compliance, each lane should run as a proper subagent.

---

## Next Actions

1. **Update design-revision-metadata.yaml** to reflect APPROVED status
2. **Build test-runner image** and validate full E2E compose flow
3. **Add Serverpod health endpoint** for proper health checks
4. **Document WARP workaround** in team onboarding docs
5. **Consider adding Makefile targets** for common operations (`make qa-up`, `make qa-down`, `make e2e-test`)

---

## Authority

- DEPLOYMENT_DISCOVERY: Persisted (deployment authority)
- QA_DISCOVERY: Persisted (qa-executor authority)
- Process improvements require human review for framework changes