# Subtask Report — deploy-qa-post-f235

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-f235
TASK_TYPE: deploy
FEATURE: redeploy QA — F-235 (agent_execution retire) + auto-escalation live
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: HEAD (deploy-time HEAD)
HEAD_SHA: 2e56eee
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`)
CANDIDATE_ID: docker-server-1 image sha256:e7b35e75b0576622abead34eec1fd6369148a051997d5252af2ebf0360f10f18 built 2026-11-02T01:50Z from HEAD 2e56eee (+ client image sha256:a7cde7224abee8ebba9f905730b8f3f25b05c821a84ebab1ba0a154b506530e6)
```

## Files touched

```text
docker/.env                                                         (deployment config, gitignored — OWNED)
docs/engineering/dispatch/tasks/deploy-qa-post-f235/report.md       (this report)
```

No repository source files read, written, or executed against beyond read-only inspection.
`OWNED_PATHS: []` held for repo files; `docker/.env` is machine-local deployment config per dispatch.

## What was executed, in order

1. **`docker/.env` wedge-unblock restored** — `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`
   was `3` (temp remediation `deploy-qa-paid-models` 2026-11-01); set to `2`, the shipped
   default (compose `:-2`), and the now-resolved remediation comment removed. Verified
   live in-container: `docker exec docker-server-1 printenv` → `2`, and boot banner
   `server.capacity.resolved ... SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2`.
2. **Pre-flight migration check** — `serverpod_migrations` on QA Postgres:
   `control_plane 20261023113614000`, equal to newest `migration_registry.txt` entry.
   Nothing pending; nothing destructive. No STOP condition.
3. **Pre-deploy state captured** — server image created 2026-11-01T20:18Z, predating both
   fix commits (`28e89f9` 20:51:57Z, `50724a0` 01:38:39Z) — rebuild genuinely required.
   Old-container error signature count (`Session or transaction ... finished|
   DatabaseQueryException`, 6 h lookback): `0`.
4. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` rebuilt the
   Flutter web app and `client` image; `compose build server` rebuilt the server image;
   `up -d` recreated `docker-server-1` at 01:50:07Z and `docker-client-1` at 01:50:10Z;
   `docker-triage-seed-1` re-ran and exited 0. `docker-postgres-1` NOT recreated
   (`Up 23 hours (healthy)`). No `down`, `-v`, `prune`, `--rmi`, or `clean` issued;
   volumes untouched.
5. **Identity verification** (verbatim below).
6. **~25 min monitoring window** (01:50–02:09Z) — paid-tier verification, zombie-reclaim
   observation, claim-expiry sampling, opencode session inspection.
7. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... time: 2026-11-02 01:50:34.627095Z
server-1  | runMode: staging
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

Worker heartbeats (read-only psql, repeatedly sampled):

```text
w-design-review-local   | idle | hb_age ~3s
w-design-revision-local | idle | hb_age ~3s
w-impl-local            | idle | hb_age ~3s
w-review-local          | idle | hb_age ~3s
w-triage-local          | busy | hb_age ~3s  (currentLoad 1 — exec 194)
```

## Fix verification

**HEAD contains both fixes.** `git merge-base --is-ancestor` on the build checkout:
`50724a0` (F-235 zombie-retire merge) ✓, `28e89f9` (auto-escalation merge) ✓, under HEAD
`2e56eee`. The deployed image `sha256:e7b35e75...` was built from this checkout at
01:50Z — the previous image (20:18Z) predated both merges.

**Paid tier live post-restart.** The queued `implement_feature` job
`jb-hnrs6ymd48-e5h1fh` dispatched at 01:51:13Z (`implementation.tick.dispatched`,
`implementation.readiness.resolved` → `/workspace-repo/shipit-platform/checkout` @
`f58d6fb1`), agent_execution id 194. Its opencode ACP session
`ses_e660bcb7affedA6aD7lZvBc778` streamed on the **paid** provider, verbatim from the
in-container log:

```text
timestamp=2026-11-02T01:52:13.822Z run=95ef858b message=stream
  providerID=openrouter modelID=deepseek/deepseek-v4.1-flash
  session.id=ses_e660bcb7affedA6aD7lZvBc778 small=false agent=build mode=primary
timestamp=... message="llm runtime selected" llm.runtime=ai-sdk
  llm.provider=openrouter llm.model=deepseek/deepseek-v4.1-flash
```

…repeated stream steps through step=24 at 01:52:48Z. Composition banner confirms
`modelPolicy {inForceModelId: openrouter/deepseek/deepseek-v4.1-flash,
inForceSource: policy}`.

**`model_execution_record` evidence:** no post-restart row yet — the record is written at
execution end and exec 194 is still in flight (see residual #2: the run stalled at
01:52:49Z on an unanswered ACP permission ask). Nearest same-env row: exec 193
(DEF-f223-test IMPLEMENTER) finished 01:49:50Z on the pre-recreate container with
`modelId=openrouter/deepseek/deepseek-v4.1-flash, provider=opencode,
totalTokens=1048576, success=t, escalationIndex=0` — the paid-tier signature, not the
`unknown`/0-token quota-dead one.

**Auto-escalation (`28e89f9`)**: present in the image; not exercised — no provider
failure occurred in the window, so `escalationIndex` stayed 0 (the healthy case).

**No stale `running` agent_execution rows accumulate.** Post-restart `running` rows: 2
— exec 194 (live, new container) and exec 191 (pre-restart zombie, see below). No new
stale rows appeared in the window.

## F-235 zombie-reclaim observation (exec 191)

Exec 191 (`agx-wx-jb-hnrruooft2-1ljcar4`, implement_feature, started 01:15:12Z on the
OLD container; its opencode process died at the 01:50:07Z recreate). Observed live:

- Its job claim `cl-hnrt35d8wv` expired 01:55:40Z; on the next tick the scheduler ran
  `_reconcileClaim` → probed liveness → **renewed** the lease to 02:05:40Z rather than
  reclaiming. Renewed again to 02:15:41Z at the next expiry.
- Why renew not reclaim: `worker_execution.agentExecutionId` is **empty** on
  in-flight rows (stamped only at the worker row's TERMINAL write, per
  `agent_execution_retirement.dart` doc). `liveSessionLivenessProbe` reads that column;
  empty → `ExecutionLiveness.unknown` → `_shouldReclaimZombie` falls to the staleness
  bound. For `implement-feature` the bound in force is `18000s` (banner
  `stalenessBoundInForce: implementation 18000`) → reclaim fires ~06:15Z unless the row
  settles earlier.
- The F-235 retirement half IS verifiably deployed and historically exercised on this
  stack: `agent_execution` rows closed at 00:29:58Z today carry reason
  `"stale running row closed: owning job already terminal (zombie reclaim orphaned the
  execution record) — F-235 class"` (earlier-iteration wording; committed wording is
  `'zombie execution reclaimed: ...'` → status `orphaned`). At the bound,
  `_reclaimZombie` derives `agx-<workerExecutionId>` for the unstamped link and closes
  the row via the `AgentExecutionRetirement` seam — code path confirmed at
  `packages/scheduler/lib/src/scheduler.dart` `_retireAgentExecutionRow` /
  `_agentExecutionIdFor` and `packages/worker_runtime/.../agent_execution_retirement.dart`.
- 37 `scheduler.tick.completed` passes in the window, ALL `failedSections: []`,
  `reconcileFailedCount: 0`.

## Residuals (verbatim, non-blocking)

1. **Boot-time schema-drift WARNING** (pre-existing, unchanged by this deploy):
   ```text
   WARNING: The database does not match the target database:
    - Table "design_revision" is not like the target database:
    - Missing Column "declared_owned_paths".
    - Missing Index "design_revision_approved_unique_per_work_item".
    - Missing Index "design_revision_declared_owned_paths_idx".
    - Table "product_credential" is not like the target database:
    - Missing Index "product_credential_active_repository_unique".
   ```
   `Latest database migration already applied.` precedes it — generated schema ahead of
   applied migrations. A repair/migration decision is a Manager/Human call.
2. **Exec 194 appears stalled on an unanswered ACP `session/request_permission`** —
   last session activity:
   ```text
   01:52:49.730Z evaluated permission=external_directory pattern=/triage-workspaces/*
     action.permission=external_directory action.pattern=* action.action=ask
   01:52:49.735Z asking id=per_199f59046001mCXv0U810sxrcB
     permission=external_directory patterns="[\"/triage-workspaces/*\"]"
   ```
   The agent tried `ls` outside its workspace; opencode issued `ask`; the platform ACP
   transport (`opencode_process_transport.dart`) has NO `request_permission` handler —
   incoming method-bearing messages go to `_notifications` unanswered. Session silent
   ~17 min while the process spins ~13% CPU. Bound only by the 4 h role budget
   (`session/prompt` timeout = `config.timeout`) → interruption ~05:51Z. It holds 1 of
   2 capacity slots meanwhile. Pre-existing gap, not a deploy regression — but worth a
   Manager look; an `external_directory=allow` opencode config or an ACP permission
   responder would close it.
3. **Capacity wedge in progress**: exec 191 (zombie, holds slot until ~06:15Z bound) +
   exec 194 (permission-stalled, holds slot until ~05:51Z budget) = cap 2/2. Queued
   `engineering_review` job `jb-hnrt8noflc-19umku5` cannot dispatch until one frees.
   No new dispatches possible for ~4 h under current state. Restoring `=3` was the
   prior lane's wedge-unblock and is deliberately NOT repeated — the dispatch directs
   `=2` and this wedge's cause differs (stall, not zombie volume).
4. **`SHIPIT_PROVISION_DURABLE_WORKSPACE` still set** in docker/.env — banner reports
   `alreadyProvisioned: true` and "may be cleared"; documented-safe. Not cleared
   (operator's call).
5. **`qa.drain.decision_refused` ×38 in the window** — same pre-existing QA-drain
   refusals as prior deploys (`considered: 2, failed: 2` pattern).
6. **`model_execution_record` post-restart row pending** — named acceptance evidence
   lands at exec 194's completion; stream-level paid-tier proof stands in the interim.
7. **In-flight `worker_execution.agentExecutionId` always empty → liveness probe can
   never return `dead`/`alive` for running executions** — every zombie waits its full
   `zombieStalenessFor` bound. The `_reclaimZombie` derived-id path still retires the
   row correctly at the bound, so this is a latency limitation, not a correctness
   defect; but it is why exec 191 renews rather than reclaims tonight.

## Validation results

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `docker/.env` restore `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2` | pass | `printenv` in container → `2`; banner `capacity.resolved ... =2` |
| pending-migration check | pass | `20261023113614000` = newest registry entry |
| `make qa-up` | pass | images built 01:50Z; containers recreated 01:50:07/10Z; postgres untouched (Up 23h) |
| `curl :8180` | pass | HTTP 200 |
| `curl :8081` title | pass | `<title>ShipIt Control Plane</title>` |
| runMode | pass | `runMode: staging` |
| 5 workers heartbeating | pass | 5/5 rows, hb_age ≤4 s throughout |
| HEAD contains 50724a0 + 28e89f9 | pass | `git merge-base --is-ancestor` both ✓ |
| paid-tier dispatch post-restart | pass (stream-level) | opencode log: `providerID=openrouter modelID=deepseek/deepseek-v4.1-flash` streaming, exec 194, 01:52Z; `model_execution_record` row pending run completion |
| no NEW stale `running` agent_execution rows | pass | only pre-existing exec 191 + live exec 194 |
| error signatures post-restart | pass | 0 `Session or transaction.../DatabaseQueryException` in 25-min window; 37/37 ticks `failedSections: []` |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 2e56eee0e45dfcabbe7dd167ffeea724be87fd7d
BUILD_COMMAND: make qa-up
SERVE_OR_RUN_COMMAND: docker compose -f docker/compose.qa.yaml up -d
ENVIRONMENT / BASE_URL: local QA compose (project docker); api :8180, ui :8081, db localhost:5432
ARTIFACTS:
  - server image sha256:e7b35e75b0576622abead34eec1fd6369148a051997d5252af2ebf0360f10f18
  - client image sha256:a7cde7224abee8ebba9f905730b8f3f25b05c821a84ebab1ba0a154b506530e6
  - in-container /root/.local/share/opencode/log/opencode.log (run=95ef858b, session ses_e660bcb7affedA6aD7lZvBc778)
  - docker compose logs server (post-restart, 0 signature hits, 37 clean ticks)
```

## Documentation updated

```text
none (operational lane; this report only)
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: STANDARD
MODEL_USED: n/a
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - any read-only lane
PROHIBITED_PARALLEL_WORK:
  - any lane issuing mutating docker/compose commands against project `docker` (shared-stack rule)
```

## Cleanup confirmation

- [x] No lane-spawned processes left running (poll loops all exited).
- [x] Temporary artifacts: none besides this report.
- [x] `git status` — only pre-existing untracked dispatch report.md files and this one;
      zero tracked-file modifications. `docker/.env` is gitignored by design.
- [x] No files modified outside authority (docker/.env = deployment config; task report).
- [x] No destructive docker ops; no volumes touched; partnerhub-test-db,
      control_plane-postgres_test-1, server-postgres_test-1 never contacted.

## Recommended next action

`MARK_DEPLOYED` — and route residual #2 (unanswered ACP `session/request_permission`
stalls implementer runs ~4 h; contributes to the cap-2 wedge blocking queued
engineering_review jb-hnrt8noflc) to the Manager for a work item.

## Structured result

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — F-235 (agent_execution retire) + auto-escalation live
REQUEST_ID: deploy-qa-post-f235
CANDIDATE_ID: docker-server-1@sha256:e7b35e75b0576622abead34eec1fd6369148a051997d5252af2ebf0360f10f18
TARGET_ENVIRONMENT: STAGING
BRANCH: main
BASE_SHA: HEAD
HEAD_SHA: 2e56eee0e45dfcabbe7dd167ffeea724be87fd7d

OWNED_PATHS: [] (repo files); docker/.env (gitignored deployment config, per dispatch)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, apps/server/lib, packages/scheduler/lib, packages/worker_runtime/lib, packages/agent_runtime/lib (read-only source inspection)]
PROHIBITED_PATHS: [all repo files (write), volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]

DURATION_SECONDS: ~1500

STEPS_EXECUTED:
  - STEP_ID: restore-concurrency-default
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T01:44Z
    COMPLETED_AT: 2026-11-02T01:46Z
    OUTPUT: "SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS 3->2 in docker/.env; remediation comment removed; confirmed live in container and boot banner"
    EVIDENCE_REFS: [docker/.env:64, printenv output, server.capacity.resolved line]
  - STEP_ID: preflight-migration-check
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T01:44Z
    COMPLETED_AT: 2026-11-02T01:45Z
    OUTPUT: "serverpod_migrations control_plane 20261023113614000 = newest registry entry; nothing pending; nothing destructive"
    EVIDENCE_REFS: [psql serverpod_migrations output, migration_registry.txt]
  - STEP_ID: rebuild-and-recreate
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T01:46Z
    COMPLETED_AT: 2026-11-02T01:50Z
    OUTPUT: "make qa-up OK; server+client images rebuilt; containers recreated 01:50:07/10Z; postgres untouched (Up 23h); no destructive ops"
    EVIDENCE_REFS: [make qa-up output, docker inspect created/image]
  - STEP_ID: identity-verification
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T01:50Z
    COMPLETED_AT: 2026-11-02T01:53Z
    OUTPUT: "runMode: staging; :8180=200; <title>ShipIt Control Plane</title>; 5/5 workers heartbeating; cap=2 resolved"
    EVIDENCE_REFS: [boot log lines, curl output, worker_registration query]
  - STEP_ID: fix-verification
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T01:53Z
    COMPLETED_AT: 2026-11-02T02:09Z
    OUTPUT: "HEAD contains 50724a0+28e89f9; exec 194 dispatched post-restart streaming openrouter/deepseek/deepseek-v4.1-flash (paid tier live); exec 191 zombie on 5h bound with renewal observed; 37 clean ticks; model_execution_record row pending run completion"
    EVIDENCE_REFS: [git merge-base, opencode.log stream lines, agent_execution/job_claim/model_execution_record queries]

ROLLBACK_TRIGGERED: NO
ROLLBACK_REASON: n/a
ROLLBACK_RESULT: n/a

POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (:8180=200; :8081 title verified; 37 clean tick passes)
  KEY_METRICS: PASS (5/5 workers hb ≤4 s; heldForSeconds 1–10 s)
  ERROR_RATES: PASS (0 DatabaseQueryException post-restart)
  MOBILE_COMPATIBILITY: NOT_APPLICABLE

OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL

DISCOVERIES:
  - RUNTIME_DISCOVERY: platform ACP transport never answers opencode
    `session/request_permission` — an `external_directory` ask stalls the agent turn
    until the role budget (4 h implementer) kills it. Exec 194 hit this at 01:52:49Z,
    holding 1/2 capacity slots. Reported to Manager via residual #2.
  - RUNTIME_DISCOVERY: in-flight worker_execution.agentExecutionId is empty until the
    terminal write, so liveSessionLivenessProbe always returns `unknown` for running
    executions — zombies renew until zombieStalenessFor bound (impl 5 h). Reclaim
    still correct at bound via derived `agx-` id (F-235 seam verified in code + prior
    QA retirements).
  - PROJECT_FACT: F-235-class agent_execution retirement previously exercised on QA at
    00:29:58Z under earlier-iteration wording ("stale running row closed... — F-235
    class"); committed wording/status now `orphaned` via storeBackedAgentExecutionRetirement.

KNOWLEDGE_PERSISTED:
  - report.md at docs/engineering/dispatch/tasks/deploy-qa-post-f235/report.md

BLOCKERS: none for the deploy itself. Operationally: cap-2 wedge (zombie exec 191 +
permission-stalled exec 194) blocks queued engineering_review jb-hnrt8noflc ~4 h —
flagged for Manager; no action taken beyond this report.
```

RESULT: DEPLOYMENT_SUCCESSFUL
