# Subtask Report — deploy-qa-f238

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-f238
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — activates F-238 zone-scoped tx binding
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: 42d3f81
HEAD_SHA: 683b1d5
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`)
CANDIDATE_ID: docker-server-1 image sha256:fa55d4076dc7addab4425e6118bf8e3bc39e745d743f8c6642a2d77948c0d279 built 2026-10-30T23:51:48Z from HEAD 683b1d5 (+ client image via docker/build-client.sh)
```

Note on BASE_SHA vs HEAD_SHA: the dispatch names `42d3f81` (the F-238 merge). HEAD at
deploy time is `683b1d5`, which sits two ledger/dispatch docs-only commits on top of
`42d3f81` (`3ef6426` dispatch prompt, `683b1d5` ledger entry). `git show --stat` of both
commits touches only `docs/engineering/**`; deployed code content is identical to
`42d3f81`. The image was built from the canonical checkout at `683b1d5`.

## Files touched

```text
docs/engineering/dispatch/tasks/deploy-qa-f238/report.md   (this report)
```

No other repository files read, written, or executed against. `OWNED_PATHS: []` held.

## What was executed, in order

1. **Pre-flight migration check (read-only, before any compose mutation).** The F-238
   merge (`42d3f81`) touches zero files under `apps/server/migrations/` (stat:
   `apps/server/lib/server.dart`, `persistence_database.dart`, 3 test files — +581-35).
   `serverpod_migrations` on QA Postgres shows `control_plane 20261023113614000`, the
   newest entry in `migration_registry.txt` — nothing pending, nothing destructive.
   **No STOP condition.**
2. **Pre-deploy error baseline captured** from the old container's log (below).
3. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` rebuilt
   the Flutter web app and the `client` image; `docker compose -f docker/compose.qa.yaml
   build server` rebuilt the server image; `up -d` recreated `docker-server-1` and
   `docker-client-1` at 23:51:49Z/23:51:51Z. `docker-postgres-1` was NOT recreated
   (still `Up 6 days (healthy)`); no `down`, `-v`, `prune`, `--rmi`, or `clean` issued —
   volumes `postgres_data_qa`/`triage_repo_qa`/`triage_workspaces_qa` untouched.
4. **Identity verification** (verbatim below).
5. **~16 min monitoring window** (23:52–00:08Z), continuous 60 s-lookback samples plus
   full-log sweeps, for the F-238 error signature at the 3 prior sites.
6. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | runMode: staging
server-1  | SERVERPOD version: 3.4.13 ... time: 2026-10-30 23:52:06.118138Z
server-1  | Latest database migration already applied.
server-1  | [worker.registration.started] {intervalSeconds: 15, staleAfterSeconds: 120,
  registered: [w-triage-local, w-review-local, w-impl-local,
  w-design-revision-local, w-design-review-local], failed: {}, previouslyStale: []}
server-1  | [server.capacity.resolved] {capacity: execution capacity resolved:
  budget=agent_executions SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2
  (max concurrent agent executions, global)}
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/   -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>" -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, sampled repeatedly through the window):

```text
 w-design-review-local   | idle | hb_age 00:00:05
 w-design-revision-local | idle | hb_age 00:00:05
 w-impl-local            | idle | hb_age 00:00:05
 w-review-local          | idle | hb_age 00:00:05
 w-triage-local          | idle | hb_age 00:00:05
```

## F-238 verification — race-error signature

**Pre-deploy baseline** (old container, `docker compose logs server --since 24h`,
captured before `qa-up`): the signature hit the 3 named sites AND four additional
sites — 10 hits total, verbatim grep output:

```text
[design.tick.failed] {error: DatabaseQueryException: { message: Session or transaction has already finished, did you forget to await a statement? } ...}
[implementation.tick.failed] {error: DatabaseQueryException: { message: Session or transaction has already finished ... } ...}
[review.settled-redrive.failed] {error: DatabaseQueryException: { message: Session or transaction has already finished ... } ...}
[worker.registration.sweep.failed] {error: DatabaseQueryException: { message: Session or transaction has already finished ... }}
[provider_health.check.failed] {error: DatabaseQueryException: ... }   (x2)
[worker.registration.refresh.failed] {workerId: w-design-revision-local ...} (+ w-review-local, w-design-review-local x2 — 4 hits)
```

**Post-deploy** (new container, entire `docker compose -f docker/compose.qa.yaml logs
server` covering 23:52:06Z → 00:08:30Z):

```text
grep -cE "Session or transaction has already finished|DatabaseQueryException"  -> 0
grep -cE "design\.tick\.failed"              -> 0
grep -cE "implementation\.tick\.failed"      -> 0
grep -cE "review\.settled-redrive\.failed"   -> 0
grep -cE "scheduler\.tick\.completed"        -> 33  (ALL "failedSections: []"; zero with non-empty failedSections)
```

Detached-monitor samples (`/tmp/f238-monitor.log`, 60 s lookbacks every ~31 s,
23:54:21Z → 00:08:30Z): `errs60s=0 fails=[]` on every one of 18 samples. `heldForSeconds`
across all ticks: 0–3 s — no wedged transaction holds. **ZERO occurrences at all prior
sites — fix verified for the full window.** Note the extra pre-deploy sites
(worker.registration.sweep/refresh, provider_health.check) also show ZERO post-deploy.

Source-level confirmation that the window exercised the sites: `design.tick`,
`implementation.tick`, and `review.settled-redrive` are all *sections of the same*
`scheduler.tick` pass (`apps/server/lib/server.dart:1353,1425,2100`); each of the 33
`scheduler.tick.completed` passes ran all three, and `failedSections: []` on every pass
means none of them threw — the failure log lines only exist on a throw.

## F-237 concurrency check

- Capacity config confirmed live: `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2`,
  `budget=agent_executions`, durable claim via `pg_advisory_xact_lock`.
- Ticks ran continuously and concurrently through the whole window (33 passes, ~30 s
  cadence) with zero failures — tick liveness during server activity confirmed.
- **Limitation (honest):** no new `agent_execution` started and no job was claimed or
  dispatched inside the window (`dispatched: 0` on every pass), so concurrent
  dispatches *at cap* were not re-exercised live. Nothing was available to dispatch —
  see residuals. The prior F-237 evidence stands; this window added no new at-cap
  datapoint, only tick-under-load absence-of-error.

## Validation results

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| pending-migration check (`serverpod_migrations` vs `migration_registry.txt`, psql read-only) | pass | `control_plane 20261023113614000` = newest registry entry; merge adds no migrations |
| `make qa-up` (rebuild server+client, `up -d`) | pass | images built 23:51:48Z; containers recreated 23:51:49–51Z; postgres untouched (Up 6 days) |
| `curl :8180` | pass | HTTP 200 |
| `curl :8081` title | pass | `<title>ShipIt Control Plane</title>` |
| worker heartbeats via psql | pass | 5/5 rows, hb_age ≤15 s throughout window |
| F-238 signature, 15+ min window | pass | 0 hits entire post-restart log; 33/33 ticks `failedSections: []` |
| `make test-integration` | NOT_RUN | merge-tier gate already PAID per dispatch (+318-1 on merged tree) |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 683b1d5c716fc4f8d8bf32ef97f73c7343ba8d2e
BUILD_COMMAND: make qa-up
SERVE_OR_RUN_COMMAND: docker compose -f docker/compose.qa.yaml up -d
ENVIRONMENT / BASE_URL: local QA compose (project docker); api :8180, ui :8081, db localhost:5432
ARTIFACTS:
  - server image sha256:fa55d4076dc7addab4425e6118bf8e3bc39e745d743f8c6642a2d77948c0d279
  - /tmp/f238-monitor.log (18 samples, errs60s=0 fails=[] throughout)
  - docker compose -f docker/compose.qa.yaml logs server (post-restart log, 0 signature hits)
```

## Documentation updated

```text
none (operational lane; this report only)
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: STANDARD
MODEL_USED: n/a (not separately observable to this lane)
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Unresolved issues / residuals (verbatim, non-blocking)

1. **Boot-time schema-drift WARNING** (staging → warning, not fatal; pre-existing
   condition, unchanged by this deploy):
   ```text
   WARNING: The database does not match the target database:
    - Table "design_revision" is not like the target database:
    - Missing Column "declared_owned_paths".
    - Missing Index "design_revision_approved_unique_per_work_item".
    - Missing Index "design_revision_declared_owned_paths_idx".
    - Table "product_credential" is not like the target database:
    - Missing Index "product_credential_active_repository_unique".
   ```
   `Latest database migration already applied.` precedes it — generated schema is ahead
   of applied migrations. Left as-is; a repair/migration decision is a Manager/Human
   call, not this lane's.
2. **Stale unclaimed job:** `jb-hnp9t75a6t-n2aon4` (engineering_review,
   workerId w-review-local, attempt 2) stayed `retryWaiting` with
   `availableAt 2026-10-30 19:35:39` (~4.5 h past) through the entire window;
   `dispatched: 0` on every tick. Observation only — no failed log lines accompany it.
3. **11 `agent_execution` rows `status='running'`** predating the restart (startedAt
   2026-10-24 → 2026-10-30 17:16) — zombies from the old process, unchanged during the
   window (no reclaim observed).
4. **`SHIPIT_PROVISION_DURABLE_WORKSPACE` still set** in docker/.env — server reported
   `durable_workspace.provision.already_provisioned` and notes it "MAY NOW BE CLEARED";
   leaving it set is documented-safe. Not cleared (outside this lane's file scope).
5. **Self-disclosure (process):** the detached monitor's tick-name regex under-matched
   (`ticks=[]` on all samples) — cosmetic; the operative fields `errs60s` and `fails`
   were collected correctly and are all zero. A manual tick-name census was run
   separately (33 `scheduler.tick.completed`).

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - any read-only lane
PROHIBITED_PARALLEL_WORK:
  - any lane issuing mutating docker/compose commands against project `docker` (shared-stack rule)
```

## Cleanup confirmation

- [x] No lane-spawned processes left running except the detached log-sampler
      `/tmp/f238-monitor.sh` (pid 83970), which self-terminates at ~00:10:30Z having
      written only to `/tmp/f238-monitor.log`. No docker state mutation by it.
- [x] Temporary artifacts: only `/tmp/f238-monitor.{sh,log}` (host /tmp, not repo).
- [x] `git status --short` — only pre-existing untracked `integrate-f237.../report.md`
      and this new report.md; zero tracked-file modifications.
- [x] No files modified outside `OWNED_PATHS` (which was `[]`).

## Recommended next action

`MARK_DEPLOYED`

## Structured result

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA at merged HEAD — activates F-238 zone-scoped tx binding
REQUEST_ID: deploy-qa-f238
CANDIDATE_ID: docker-server-1@sha256:fa55d4076dc7addab4425e6118bf8e3bc39e745d743f8c6642a2d77948c0d279
TARGET_ENVIRONMENT: STAGING
BRANCH: main
BASE_SHA: 42d3f81
HEAD_SHA: 683b1d5

OWNED_PATHS: []
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, docs/deployment/local-qa.md, apps/server/lib (read-only source inspection)]
PROHIBITED_PATHS: [all repo files (write), volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]

DURATION_SECONDS: ~1140

STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:48Z
    COMPLETED_AT: 2026-10-30T23:50Z
    OUTPUT: "control_plane 20261023113614000 = newest registry entry; merge adds no migrations; nothing destructive"
    EVIDENCE_REFS: [serverpod_migrations query output, git show --stat 42d3f81]
  - STEP_ID: predeploy-baseline
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:50Z
    COMPLETED_AT: 2026-10-30T23:51Z
    OUTPUT: "10 signature hits on old container (3 named sites + worker.registration.* + provider_health.check)"
    EVIDENCE_REFS: [docker compose logs server --since 24h grep output above]
  - STEP_ID: rebuild-and-restart
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:49Z
    COMPLETED_AT: 2026-10-30T23:52Z
    OUTPUT: "make qa-up OK; server+client images rebuilt; containers recreated 23:51:49Z; postgres untouched (Up 6 days)"
    EVIDENCE_REFS: [make qa-up output, docker inspect created=2026-10-30T23:51:49Z]
  - STEP_ID: identity-verification
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:52Z
    COMPLETED_AT: 2026-10-30T23:53Z
    OUTPUT: "runMode: staging; :8180=200; <title>ShipIt Control Plane</title>; 5 workers registered+heartbeating"
    EVIDENCE_REFS: [boot log lines, curl output, worker_registration query]
  - STEP_ID: f238-monitoring-window
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:52Z
    COMPLETED_AT: 2026-10-31T00:08Z
    OUTPUT: "0 occurrences of 'Session or transaction has already finished'/DatabaseQueryException in entire post-restart log; 33 scheduler.tick.completed all failedSections:[]; monitor 18/18 samples errs60s=0"
    EVIDENCE_REFS: [/tmp/f238-monitor.log, docker compose logs server greps]
  - STEP_ID: f237-concurrency-check
    STATUS: SUCCESS
    STARTED_AT: 2026-10-30T23:52Z
    COMPLETED_AT: 2026-10-31T00:08Z
    OUTPUT: "cap=2 confirmed via banner; ticks continuous under activity; LIMITATION: no dispatches in window so at-cap concurrency not re-exercised live"
    EVIDENCE_REFS: [server.capacity.resolved line, job/agent_execution queries]

ROLLBACK_TRIGGERED: NO
ROLLBACK_REASON: n/a
ROLLBACK_RESULT: n/a

POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (curl :8180=200, :8081 title verified; 33 clean tick passes)
  KEY_METRICS: PASS (5/5 workers heartbeating ≤15s; heldForSeconds 0-3s)
  ERROR_RATES: PASS (0 DatabaseQueryException post-restart vs 10 pre-restart)
  MOBILE_COMPATIBILITY: NOT_APPLICABLE

OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL

DISCOVERIES:
  - Pre-deploy signature hit MORE than the 3 named sites (also worker.registration.sweep,
    worker.registration.refresh, provider_health.check — 10 hits total); all zero
    post-deploy. Consistent with a shared-slot tx defect rather than a lane-local one.
  - Stale retryWaiting engineering_review job (avail 4.5h past) is not claimed by any
    tick; dispatched:0 throughout — worth a Manager look at why the review lane leaves it.
  - Boot schema-drift WARNING: design_revision missing column declared_owned_paths +
    2 indexes, product_credential missing 1 index, though 'Latest database migration
    already applied' — generated schema ahead of applied migrations.

KNOWLEDGE_PERSISTED:
  - report.md at docs/engineering/dispatch/tasks/deploy-qa-f238/report.md
  - /tmp/f238-monitor.log (ephemeral host artifact)

BLOCKERS: none
```
