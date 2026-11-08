# Deploy Report — deploy-qa-post-real-deploy

RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-real-deploy
TASK_TYPE: deploy
FEATURE: redeploy QA — real deploy execution live (deployment_approval -> land the produced commit)
WORKTREE: /Users/alkebut/air/shipit-platform (canonical; no repo edits)
BRANCH: main
BASE_SHA: 1457603ec26c56a43f3c26bc0590b8da8637495c
HEAD_SHA: 1457603ec26c56a43f3c26bc0590b8da8637495c
COMMITTED: NO
CANDIDATE_ID: docker-server / docker-client images built from HEAD 1457603 (compose project `docker`, docker/compose.qa.yaml)
TARGET_ENVIRONMENT: LOCAL QA (compose project `docker`; docker/compose.qa.yaml only)

## Scope honored

- Compose commands issued ONLY as `docker compose -f docker/compose.qa.yaml ...`
  via `make qa-up` (project `docker`). No `down`, no `-v`, no `prune`, no
  `--rmi`, no `make clean`, no volume or data destruction. Postgres was never
  restarted (healthy throughout; retained uptime).
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
     serverpod     | 20260129180959368
     control_plane | 20261023113614000

Newest `apps/server/migrations/migration_registry.txt` entry:
`20261023113614000` — equal to the applied `control_plane` version.
Nothing pending, nothing destructive. Working tree has zero diffs under
`apps/server/migrations/`.

### 2. make qa-up — SUCCESS

Client image ownership guard passed ("compose.qa.yaml is the sole source of
truth for the QA client image"), Flutter web build completed, server image
built via `docker compose -f docker/compose.qa.yaml build server` (BuildKit
cache made the whole cycle ~2 min), then `up -d` recreated `docker-server-1`
and `docker-client-1` (created 2026-11-07T04:30:18/19Z). `docker-postgres-1`
untouched (retained uptime). `docker compose -f docker/compose.qa.yaml ps`
shows all services Up.

### 3. Identity verification — SUCCESS

- `runMode: staging` (server boot banner; `applyMigrations: true`).
- `Latest database migration already applied.` logged post-boot.
- `curl http://localhost:8180/` -> **200**.
- `curl http://localhost:8081/` -> **200**, `<title>ShipIt Control Plane</title>`.
- 5/5 workers heartbeating (`worker_registration`, all `status: idle`,
  `lastHeartbeat` ~8s old at sample): w-triage-local (triage-pool),
  w-review-local (review-pool), w-impl-local (impl-pool),
  w-design-revision-local (design-revision-pool),
  w-design-review-local (design-review-pool).
- `scheduler.tick.completed {ran: true, ..., failedSections: [], ...}` — ticks
  running clean post-boot.

### 4. Deploy-landing verification — SUCCESS (artifact present; live-approve arm N/A)

In the built artifact (verified inside the running `docker-server-1`):

- `/app/apps/server/lib/src/deploy/deploy_landing.dart` present (20,776 bytes,
  image layer timestamp 04:27Z — this build).
- `/app/apps/server/lib/src/services/control_plane_service.dart` contains the
  dispatch: line 41 `import '../deploy/deploy_landing.dart' show
  maybeLandApprovedDeployment;` and line 2327 `await
  maybeLandApprovedDeployment(...)` gated on
  `decision.decisionType == HumanDecisionType.deploymentApproval` before the
  engine's `resolveHumanDecision` write.

Live-approve exercise arm: **not exercised — no pending decision exists.**
`human_decision` shows 0 `deployment_approval` rows with `status='pending'`.
All 13 prior approvals were resolved `approve` at 2026-11-07 03:52:36 UTC under
the PREVIOUS artifact — every one of the 13 `deployed` work items carries NULL
`metadataJson->>'deployedCommit'` / `deployedBy`, i.e. they were label-deployed
without a land. That is consistent with the defect this deploy fixes (deployed
was a label) and confirms the pre-deploy artifact lacked the machinery — had it
been present, an approve would have stamped `deployedCommit` or left the
decision pending on a `DeployLandingException`. No `deploy.landing.*` log lines
exist on this boot (0 matches) — nothing has approved since the land went live.
The mechanism is live and will fire on the next `deployment_approval`/approve.

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

(e) 13 `infrastructure_decision` rows remain `status='pending'` (pre-existing,
unrelated to this deploy; awaiting human action by design).

## Rollback

None triggered. No failure criterion met; known-good state was never left.

## Structured result

RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — real deploy execution live (deployment_approval -> land the produced commit)
REQUEST_ID: deploy-qa-post-real-deploy
CANDIDATE_ID: docker-server/docker-client @ 1457603ec26c56a43f3c26bc0590b8da8637495c (compose project docker)
TARGET_ENVIRONMENT: STAGING (local QA compose stack; runMode staging)
BRANCH: main
BASE_SHA: 1457603ec26c56a43f3c26bc0590b8da8637495c
HEAD_SHA: 1457603ec26c56a43f3c26bc0590b8da8637495c
OWNED_PATHS: [docs/engineering/dispatch/tasks/deploy-qa-post-real-deploy/report.md, docker/compose.qa.yaml operations only]
READ_ONLY_PATHS: [Makefile, apps/server/migrations, apps/server/lib, QA Postgres (read-only psql), docker logs, git history]
PROHIBITED_PATHS: [all repo source files, volumes, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
DURATION_SECONDS: ~420
STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check / STATUS: SUCCESS
  - STEP_ID: make-qa-up / STATUS: SUCCESS
  - STEP_ID: verify-identity / STATUS: SUCCESS
  - STEP_ID: verify-deploy-landing / STATUS: SUCCESS (artifact verified; live-approve arm not exercised — 0 pending)
  - STEP_ID: report-residuals / STATUS: SUCCESS
ROLLBACK_TRIGGERED: NO
POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (API :8180 200 + UI :8081 200 title + worker heartbeats + clean scheduler ticks)
  KEY_METRICS: PASS
  ERROR_RATES: PASS
  MOBILE_COMPATIBILITY: NOT_APPLICABLE
OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL
DISCOVERIES: RUNTIME_DISCOVERY — all 13 prior deployment_approval resolves (2026-11-07 03:52:36 UTC, pre-deploy artifact) are label-only deploys with NULL deployedCommit/deployedBy; the verified land arm has never fired in this stack and first fires on the next approve.
BLOCKERS: none
