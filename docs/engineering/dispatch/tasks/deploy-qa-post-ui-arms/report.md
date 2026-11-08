# Deploy Report — deploy-qa-post-ui-arms

RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-ui-arms
TASK_TYPE: deploy
FEATURE: redeploy QA — reland + reroute visible in actionContext/UI (F-260 + F-262)
WORKTREE: /Users/alkebut/air/shipit-platform (canonical; no repo edits)
BRANCH: main
BASE_SHA: 6779b84239c1eb1e52c8519fc7e68c064fee3bfb
HEAD_SHA: 6779b84239c1eb1e52c8519fc7e68c064fee3bfb
COMMITTED: NO
CANDIDATE_ID: docker-server sha256:31e418c3b269b825aa3755f1279676a6d66a5c94db8d2791c5327e9c11bed575 / docker-client images built from HEAD 6779b84 (compose project `docker`, docker/compose.qa.yaml)
TARGET_ENVIRONMENT: LOCAL QA (compose project `docker`; docker/compose.qa.yaml only)

## Scope honored

- Compose commands issued ONLY as `docker compose -f docker/compose.qa.yaml ...`
  via `make qa-up` (project `docker`). No `down`, no `-v`, no `prune`, no
  `--rmi`, no `make clean`, no volume or data destruction. `docker-postgres-1`
  never restarted (retained uptime — Up 22h at redeploy).
- Prohibited stacks untouched: partnerhub-test-db (9090),
  control_plane-postgres_test-1 (9099), server-postgres_test-1 / teamhub
  postgres (9190) — no command referenced them (listed read-only via
  `docker ps` only).
- Zero repo file edits (only this report.md, the lane's execution log).
- No secret values printed; docker/.env never read.

## Steps executed

### 1. preflight-migration-check — SUCCESS (read-only, before any compose mutation)

QA Postgres `serverpod_migrations`:

    module     |      version
    ---------------+-------------------
     control_plane | 20261023113614000
     serverpod     | 20260129180959368

Newest `apps/server/migrations/migration_registry.txt` entry:
`20261023113614000` — equal to the applied `control_plane` version.
Nothing pending, nothing destructive. Boot later confirmed:
`Latest database migration already applied.`

### 2. make qa-up — SUCCESS (~50 min wall, host under load)

- Client image ownership guard passed ("compose.qa.yaml is the sole source of
  truth for the QA client image; the build script names nothing.").
- Flutter web release build (dart2wasm + dart2js) completed; client image
  `docker-client` rebuilt through the compose-ownership path.
- Server image `docker-server` rebuilt via
  `docker compose -f docker/compose.qa.yaml build server`
  (BuildKit; image sha256:31e418c3b269... — the 45-min upper end of the
  expected 2-45min window under sustained host load).
- `docker compose -f docker/compose.qa.yaml up -d` recreated
  `docker-server-1` and `docker-client-1` (Created 2026-11-08T02:02:05-07Z);
  `docker-postgres-1` untouched (Up 22h, healthy); `docker-triage-seed-1` ran
  its no-op branch ("triage repo already initialised") and exited.
- Final `compose ps`: all three services Up.

### 3. Identity verification — SUCCESS

- Boot banner: `runMode: staging`, `applyMigrations: true`,
  `SERVERPOD version: 3.4.13 ... time: 2026-11-08 02:02:29Z`,
  `SERVERPOD initialized`.
- `curl http://localhost:8180/` -> **200**.
- `curl http://localhost:8081/` -> **200**, `<title>ShipIt Control Plane</title>`.
- 5/5 workers heartbeating (`worker_registration`, all `status: idle`,
  `hb_age_s` ~6s at sample): triage-pool, review-pool, impl-pool,
  design-revision-pool, design-review-pool
  (registered: [w-triage-local, w-review-local, w-impl-local,
  w-design-revision-local, w-design-review-local]).
- `[scheduler.tick.completed] {ran: true, dispatched: 0, handledOff: 0,
  sweepEnqueued: 0, failedSections: [], reconcileFailed: [],
  reconcileFailedCount: 0, overlappedTicks: 0, heldForSeconds: 1, code: null}`
  — ticks clean post-boot.
- `[agent_runtime.adapter_healthy] {providerId: opencode, runtimeTypeId:
  opencode, version: 1.19.5, agentName: OpenCode}` — probe HEALTHY this boot
  (prior deploy saw a 30s boot-probe timeout under host load; no timeout here).

### 4. actionContext offer verification — SUCCESS

**Live endpoint probes** (`POST :8180/workItemActionEndpoints/actionContext`):

Stamped `deployed` + idle items -> `[reroute]`, 3/3 probed
(defect-DEF-1791684804452198, defect-DEF-1791686704991884, DEF-f223-test —
all return the identical payload):

```json
"state": "deployed",
"actions": [
  {
    "__className__": "WorkItemActionView",
    "action": "reroute",
    "toState": "implementation_ready",
    "confirmRequired": true,
    "destructive": false,
    "attemptLimit": 0
  }
]
```

All 7 `deployed` rows share the same durable facts (`deployedCommit` stamp
present, zero jobs in pending/claimed/running/enqueued on any deployed item
=> `deployedIdle` true), so all 7 offer `[reroute]`.

**Unstamped case `[reland, reroute]`** — verified in the running artifact;
NO unstamped deployed row exists in QA to probe live:

- Inside running `docker-server-1` (`/app`, file timestamps Nov 8 01:59 UTC =
  this build):
  - `deploy_landing.dart:154` — `bool deployRelandIsOwed(WorkItem item)`.
  - `work_item_action_endpoints.dart` — `actionContext` (line 525) computes
    `relandOwed: deployRelandIsOwed(item)` (596) and `deployedIdle` (582);
    `actionsFor` deployed arm (1881): `if (relandOwed) WorkItemActionView(
    action: 'reland' ...)` (1883-1885) then the reroute offer gated on
    `isLegalTransition(deployed, implementationReady)` (1894-1904) — i.e.
    unstamped => `[reland, reroute]`, stamped => `[reroute]`, verbatim.
  - Generated `endpoints.dart` registers `actionContext` (1925-1926),
    `relandDeployedWorkItem` (2102-2103), `rerouteToImplementation`
    (2141-2142).
- Why no live unstamped row: QA Postgres `operator_action` ledger shows all 7
  currently-deployed items carry a `reland` action row dated 2026-11-07
  (the exact 7 ids now stamped) — the label-only items were re-landed
  end-to-end earlier today, which is why zero
  `state='deployed' AND deployedCommit IS NULL/''` rows remain (verified 0).
  Six `reroute` rows (also 2026-11-07) cover the sibling path on the items
  that were sent back.

**UI panel code in built bundle** — served `main.dart.js`
(3,501,986 bytes, image timestamp Nov 8 02:00 UTC = this build) inside
`docker-client-1`:

    "It says it is deployed"  : 1   (relandPanelHeading)
    "nothing was landed"      : 2   (relandPanelExplanation)
    "It is deployed"          : 1   (reroutePanelHeading)
    "Land it now"             : 2   (relandActionLabel)
    "Send it back"            : 3   (rerouteActionLabel)
    "reland"                  : 12  (wire token)
    "reroute"                 : 11  (wire token)

### 5. Residuals — verbatim (pre-existing; none caused by this deploy)

(a) Post-boot WARNING (staging makes it a warning, not fatal; identical
residual in prior deploy reports — generated schema ahead of applied
migrations; repair decision is a Manager/Human call):

    WARNING: The database does not match the target database:
     - Table "design_revision" is not like the target database:
     - Missing Column "declared_owned_paths".
     - Missing Index "design_revision_approved_unique_per_work_item".
     - Missing Index "design_revision_declared_owned_paths_idx".
     - Table "product_credential" is not like the target database:
     - Missing Index "product_credential_active_repository_unique".
    Hint: Did you forget to run `serverpod generate`, apply the migrations (--apply-migrations), or run a repair migration (--apply-repair-migration)?

(b) Durable-workspace provision instruction already satisfied (pre-existing
operator instruction state; the banner itself says it MAY NOW BE CLEARED):

    [durable_workspace.provision.refused] {code: WORKSPACE_ALREADY_PROVISIONED, productId: shipit-platform, ...}
    [durable_workspace.provision.already_provisioned] {productId: shipit-platform, repositoryId: shipit-platform, pinnedRevision: f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2, repositoryPath: /workspace-repo/shipit-platform/checkout, ...}

(c) Work-entry sweep gate (documented design-revision.md §15 gate — a
deliberate disabled state, not a fault; printed on every start):

    [work_entry.sweep.disabled] {enabled: false, enableWith: SHIPIT_WORK_ENTRY_SWEEP=<one of [1, true, yes, on]>, ...}

(d) `SHIPIT_TICK_MAX_HOLD_SECONDS: "3600"` in-force override (instrumentation
only, F-79/F-88; deliberate compose setting):

    [server.tick_hold.resolved] {boundSeconds: 3600, source: configured, derivedDefaultSeconds: 61200}

(e) Documented ADR 0018 A1/A4 credential fallback explicitly selected
(pre-existing; name-referenced only, no values):

    [baseline.credential.secret_provider.fallback_selected] {provider: local_file, directory: /var/lib/shipit/secrets, mode: 600, adr: ADR 0018 A1/A4 fallback (local secret store), selection: explicit (SHIPIT_SECRET_PROVIDER=local_file), isDocumentedFallback: true}
    [durable_workspace.credential.secret_provider.fallback_selected] {provider: local_file, ...}

(f) 17 `human_decision` rows remain `status='pending'` (pre-existing,
unrelated to this deploy; awaiting human action by design).

## Rollback

None triggered. No failure criterion met; known-good state was never left
(postgres untouched throughout; old containers served until the new images
replaced them).

## Discoveries

- RUNTIME_DISCOVERY: the opencode adapter health probe succeeded at boot this
  deploy (`adapter_healthy`), where the prior deploy observed a 30s
  TimeoutException under heavy host load — boot-probe timeouts are load
  sensitive, not a regression.
- RUNTIME_DISCOVERY: QA now has ZERO unstamped `deployed` items — the 13
  label-only items are resolved (7 relanded+stamped, ledger-proven; the
  rest rerouted). The `[reland, reroute]` arm has no live row to exercise;
  future UI-arm deploys should note artifact-level verification is the
  ceiling unless an operator lands a fresh label-only item first.
- PROJECT_FACT: pending human-decision rows live in `human_decision`
  (17 pending), not `infrastructure_decision` — the earlier report's table
  name no longer resolves (relation absent); same pending-decision concept.

KNOWLEDGE_PERSISTED: report.md only (lane authority ceiling).

## Structured result

RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — reland + reroute visible in actionContext/UI (F-260 + F-262)
REQUEST_ID: deploy-qa-post-ui-arms
CANDIDATE_ID: docker-server sha256:31e418c3b269 / docker-client @ 6779b84239c1eb1e52c8519fc7e68c064fee3bfb (compose project docker)
TARGET_ENVIRONMENT: STAGING (local QA compose stack; runMode staging)
BRANCH: main
BASE_SHA: 6779b84239c1eb1e52c8519fc7e68c064fee3bfb
HEAD_SHA: 6779b84239c1eb1e52c8519fc7e68c064fee3bfb
OWNED_PATHS: [docs/engineering/dispatch/tasks/deploy-qa-post-ui-arms/report.md, docker/compose.qa.yaml operations only]
READ_ONLY_PATHS: [Makefile, apps/server/migrations, apps/server/lib, apps/control_plane/lib, QA Postgres (read-only psql), docker logs, git history]
PROHIBITED_PATHS: [all repo source files, volumes, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
DURATION_SECONDS: ~3600
STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check / STATUS: SUCCESS
  - STEP_ID: make-qa-up / STATUS: SUCCESS (~50 min; server image rebuild under host load)
  - STEP_ID: verify-identity / STATUS: SUCCESS
  - STEP_ID: verify-actionContext-offers / STATUS: SUCCESS (stamped arm [reroute] live-verified 3/3; unstamped arm [reland, reroute] verified in running artifact + ledger — no unstamped row exists)
  - STEP_ID: report-residuals / STATUS: SUCCESS
ROLLBACK_TRIGGERED: NO
ROLLBACK_REASON:
ROLLBACK_RESULT:
POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (API :8180 200 + UI :8081 200 title + live actionContext POSTs + worker heartbeats + clean scheduler ticks)
  KEY_METRICS: PASS
  ERROR_RATES: PASS
  MOBILE_COMPATIBILITY: NOT_APPLICABLE
OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL
DISCOVERIES: see above (2 RUNTIME_DISCOVERY, 1 PROJECT_FACT)
KNOWLEDGE_PERSISTED: this report
BLOCKERS: none
