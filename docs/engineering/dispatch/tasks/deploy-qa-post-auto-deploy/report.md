# Deploy Report — deploy-qa-post-auto-deploy

RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-auto-deploy
TASK_TYPE: deploy
FEATURE: redeploy QA — runDeployGateSweep live (qa_passed -> deploying + deploymentApproval -> Needs You)
WORKTREE: /Users/alkebut/air/shipit-platform (canonical; no repo edits)
BRANCH: main
BASE_SHA: 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e
HEAD_SHA: 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e
COMMITTED: NO
CANDIDATE_ID: docker-server / docker-client images built from HEAD 3fd55e0 (compose project `docker`, docker/compose.qa.yaml)
TARGET_ENVIRONMENT: LOCAL QA (compose project `docker`; docker/compose.qa.yaml only)

## Scope honored

- Compose commands issued ONLY as `docker compose -f docker/compose.qa.yaml ...`
  via `make qa-up` (project `docker`). No `down`, no `-v`, no `prune`, no
  `--rmi`, no `make clean`, no volume or data destruction. Postgres was never
  restarted (4 days uptime, healthy, preserved).
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
Nothing pending, nothing destructive. Last migration-touching commit was
`73133b6`; working tree has zero diffs under `apps/server/migrations/`.

### 2. make qa-up — SUCCESS

Client image ownership guard passed ("compose.qa.yaml is the sole source of
truth for the QA client image"), Flutter web build completed, server image
built via `docker compose -f docker/compose.qa.yaml build server`, then
`up -d` recreated `docker-server-1` and `docker-client-1`
(created 2026-11-04 23:50:40/41 -0500). `docker-postgres-1` and
`docker-triage-seed-1` untouched (postgres 4 days uptime retained).
`docker compose -f docker/compose.qa.yaml ps` shows all three services Up.

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

### 4. Deploy-gate sweep verification — SUCCESS

Tick is `Timer.periodic(Duration(seconds: 30))` (server.dart:1900); the sweep
section is wired at server.dart:1648 (`runDeployGateSweep`, own try/catch).

Before first tick: `work_item` counts — `qa_passed: 13`, `draft: 2`,
`agent_completed: 1`, `agent_executing: 1`.

After one tick (decision `requestedAt` 2026-11-05T04:51:33Z):

    [deploy.sweep.completed] {considered: 13, advanced: 13, gateRaised: 0,
      deferred: 0, faulted: 0, awaitingHuman: 13}

13x `[deploy.sweep.item.advanced]` log lines, one per item, each naming its
`artifactId` (`artifact-deploy-<wi>-sweep-v<N>`) and `decisionId`.

Post-sweep `work_item` counts: `waiting_for_human_decision: 13`,
`draft: 2`, `agent_completed: 1`, `agent_executing: 1`. Every one of the 13
carries a non-null `blockingHumanDecisionId`.

`human_decision` rows for all 13 blocking ids: `decisionType
deployment_approval`, `status pending`, `blocking t`.

`pendingDecisions` (Needs You) — `POST :8081/api/homeEndpoints/pendingDecisions`
-> HTTP 200, **count: 13**, every entry `decisionType: deployment_approval`,
`status: pending`, `blocking: true`, `metadataJson.raisedBy:
deploy_gate_sweep`, options `approve` ("Deploy it") / `reject` ("Do not
deploy"), `workflowState: deploying`. The surface the defect report said was
empty now lists all 13.

`scheduler.tick.completed {ran: true, ..., failedSections: [], ...}` — the
sweep threw nothing; no `deploy.sweep.failed` or `deploy.sweep.item.faulted`
lines exist.

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

Note: the `Missing Column "declared_owned_paths"` line is new relative to
prior reports, which cited only the indexes — consistent with the schema
drift noted at `design_revision`; still reported verbatim, still a
Manager/Human decision.

(b) Durable-workspace provision instruction already satisfied (pre-existing
operator instruction state; the banner itself says it MAY NOW BE CLEARED):

    [durable_workspace.provision.refused] {code: WORKSPACE_ALREADY_PROVISIONED, ...}
    [durable_workspace.provision.already_provisioned] {productId: shipit-platform,
      pinnedRevision: f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2, ...}

(c) Work-entry sweep gate (documented design-revision.md §15 gate — a
deliberate disabled state, not a fault; printed on every start):

    [work_entry.sweep.disabled] {enabled: false, enableWith:
      SHIPIT_WORK_ENTRY_SWEEP=<one of [1, true, yes, on]>, ...}

(d) `SHIPIT_TICK_MAX_HOLD_SECONDS: "3600"` in-force override (instrumentation
only, F-79/F-88; deliberate compose setting):

    [server.tick_hold.resolved] {boundSeconds: 3600, source: configured,
      derivedDefaultSeconds: 61200}

## Rollback

None triggered. No failure criterion met; known-good state was never left.

## Structured result

RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — runDeployGateSweep live (qa_passed -> deploying + deploymentApproval -> Needs You)
REQUEST_ID: deploy-qa-post-auto-deploy
CANDIDATE_ID: docker-server/docker-client @ 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e (compose project docker)
TARGET_ENVIRONMENT: STAGING (local QA compose stack; runMode staging)
BRANCH: main
BASE_SHA: 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e
HEAD_SHA: 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e
OWNED_PATHS: [docs/engineering/dispatch/tasks/deploy-qa-post-auto-deploy/report.md, docker/compose.qa.yaml operations only]
READ_ONLY_PATHS: [Makefile, apps/server/migrations, apps/server/lib, QA Postgres (read-only psql), docker logs, git history]
PROHIBITED_PATHS: [all repo source files, volumes, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
DURATION_SECONDS: ~600
STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check / STATUS: SUCCESS
  - STEP_ID: make-qa-up / STATUS: SUCCESS
  - STEP_ID: verify-identity / STATUS: SUCCESS
  - STEP_ID: verify-deploy-gate-sweep / STATUS: SUCCESS
  - STEP_ID: report-residuals / STATUS: SUCCESS
ROLLBACK_TRIGGERED: NO
POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (pendingDecisions endpoint exercised end-to-end; 13 deployment_approval decisions surfaced)
  KEY_METRICS: PASS
  ERROR_RATES: PASS
  MOBILE_COMPATIBILITY: NOT_APPLICABLE
OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL
BLOCKERS: none
