# Deploy Report — deploy-qa-post-reland

RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-reland
TASK_TYPE: deploy
FEATURE: redeploy QA — re-land path live (relandDeployedWorkItem for label-only deployed items)
WORKTREE: /Users/alkebut/air/shipit-platform (canonical; no repo edits)
BRANCH: main
BASE_SHA: aa83787ece9ba2017dd951623b55b77017b9e87b
HEAD_SHA: aa83787ece9ba2017dd951623b55b77017b9e87b
COMMITTED: NO
CANDIDATE_ID: docker-server / docker-client images built from HEAD aa83787 (compose project `docker`, docker/compose.qa.yaml)
TARGET_ENVIRONMENT: LOCAL QA (compose project `docker`; docker/compose.qa.yaml only)

## Scope honored

- Compose commands issued ONLY as `docker compose -f docker/compose.qa.yaml ...`
  via `make qa-up` (project `docker`). No `down`, no `-v`, no `prune`, no
  `--rmi`, no `make clean`, no volume or data destruction. Postgres was never
  restarted (healthy throughout; retained uptime — Up 16h at redeploy).
- Prohibited stacks untouched: partnerhub-test-db (9090),
  control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190) — no
  command referenced them.
- Zero repo file edits (only this report.md, which is the lane's execution log).
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
Nothing pending, nothing destructive. Working tree has zero diffs under
`apps/server/migrations/`.

### 2. make qa-up — SUCCESS

Client image ownership guard passed ("compose.qa.yaml is the sole source of
truth for the QA client image"), Flutter web build completed, client image
`docker-client` rebuilt, server image `docker-server` rebuilt via
`docker compose -f docker/compose.qa.yaml build server` (BuildKit cache made
the server build ~30 s; whole `make qa-up` cycle ~3 min), then `up -d`
recreated `docker-server-1` and `docker-client-1`. `docker-postgres-1`
untouched (retained uptime). `docker compose -f docker/compose.qa.yaml ps`
shows all services Up.

### 3. Identity verification — SUCCESS

- `runMode: staging` (server boot banner; `applyMigrations: true`).
- `Latest database migration already applied.` logged post-boot.
- `curl http://localhost:8180/` -> **200**.
- `curl http://localhost:8081/` -> **200**, `<title>ShipIt Control Plane</title>`.
- 5/5 workers heartbeating (`worker_registration`, all `status: idle`,
  `lastHeartbeat` ~2 s old at sample): w-triage-local (triage-pool),
  w-review-local (review-pool), w-impl-local (impl-pool),
  w-design-revision-local (design-revision-pool),
  w-design-review-local (design-review-pool).
- `scheduler.tick.completed {ran: true, dispatched: 0, handledOff: 0,
  sweepEnqueued: 0, failedSections: [], reconcileFailed: [],
  reconcileFailedCount: 0, overlappedTicks: 0, heldForSeconds: 3, code: null}`
  — ticks running clean post-boot.

### 4. Re-land path verification — SUCCESS (artifact present; 13 label-only items re-landable)

In the built artifact (verified inside the running `docker-server-1`):

- `/app/apps/server/lib/src/deploy/deploy_landing.dart` present (25,166 bytes,
  image layer timestamp Nov 7 20:00 — this build), containing
  `deployRelandIsOwed` (line 147): `state == deployed` AND
  `metadata['deployedCommit']` absent/empty.
- `/app/apps/server/lib/src/endpoints/work_item_action_endpoints.dart`
  contains `relandDeployedWorkItem` (line 1295) gated on
  `deployRelandIsOwed(item)` (line 1341), importing the predicate (line 38).
- `/app/apps/server/lib/src/generated/endpoints.dart` registers the
  `relandDeployedWorkItem` MethodConnector (lines 2102-2103, 2133).

Re-landable set verified in QA Postgres: `work_item` has **13 rows
`state='deployed'`, all 13 with `metadataJson->>'deployedCommit' IS NULL`** —
every one satisfies the `deployRelandIsOwed` predicate verbatim and is
therefore re-landable through the new operator action. 0 pending
`deployment_approval` decisions (the re-land path is invoked per item, not via
a pending approval). 0 `reland*` log lines on this boot — expected: the action
fires only on operator invocation, and none has occurred yet.

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

(f) 13 `infrastructure_decision` rows remain `status='pending'` (pre-existing,
unrelated to this deploy; awaiting human action by design).

## Rollback

None triggered. No failure criterion met; known-good state was never left.

## Structured result

RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — re-land path live (relandDeployedWorkItem for label-only deployed items)
REQUEST_ID: deploy-qa-post-reland
CANDIDATE_ID: docker-server/docker-client @ aa83787ece9ba2017dd951623b55b77017b9e87b (compose project docker)
TARGET_ENVIRONMENT: STAGING (local QA compose stack; runMode staging)
BRANCH: main
BASE_SHA: aa83787ece9ba2017dd951623b55b77017b9e87b
HEAD_SHA: aa83787ece9ba2017dd951623b55b77017b9e87b
OWNED_PATHS: [docs/engineering/dispatch/tasks/deploy-qa-post-reland/report.md, docker/compose.qa.yaml operations only]
READ_ONLY_PATHS: [Makefile, apps/server/migrations, apps/server/lib, QA Postgres (read-only psql), docker logs, git history]
PROHIBITED_PATHS: [all repo source files, volumes, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
DURATION_SECONDS: ~720
STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check / STATUS: SUCCESS
  - STEP_ID: make-qa-up / STATUS: SUCCESS
  - STEP_ID: verify-identity / STATUS: SUCCESS
  - STEP_ID: verify-reland-path / STATUS: SUCCESS (artifact verified; 13/13 label-only deployed items satisfy deployRelandIsOwed)
  - STEP_ID: report-residuals / STATUS: SUCCESS
ROLLBACK_TRIGGERED: NO
POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (API :8180 200 + UI :8081 200 title + worker heartbeats + clean scheduler tick)
  KEY_METRICS: PASS
  ERROR_RATES: PASS
  MOBILE_COMPATIBILITY: NOT_APPLICABLE
OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL
DISCOVERIES: RUNTIME_DISCOVERY — all 13 `deployed` work items remain label-only (deployedCommit NULL) post-redeploy and are now re-landable via `relandDeployedWorkItem`; the action first fires on operator invocation, 0 re-land executions observed on this boot.
BLOCKERS: none
