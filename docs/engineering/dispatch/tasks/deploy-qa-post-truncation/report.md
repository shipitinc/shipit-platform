# Subtask Report — deploy-qa-post-truncation

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-truncation
TASK_TYPE: deploy
FEATURE: redeploy QA — field-truncation fix (all human-input pages render full text)
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: HEAD (deploy-time HEAD)
HEAD_SHA: 7ace9efdea8aa88244fccdcc429d06b772488956
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`)
CANDIDATE_ID: docker-client image 089c30cac3c2 built 2026-11-02T12:07:46-05:00 from HEAD 7ace9ef;
  docker-server image d2ab55a72f0d (built 05:03Z, fully CACHED this run — unchanged, correct)
```

## Files touched

```text
docs/engineering/dispatch/tasks/deploy-qa-post-truncation/report.md   (this report)
/tmp/qa-main-old.dart.js, /tmp/qa-main-new.dart.js                    (bundle captures, machine-local)
```

Zero repository source files written. `OWNED_PATHS: []` held for repo files.

## What was executed, in order

1. **Pre-flight migration check** — `serverpod_migrations` on QA Postgres:
   `control_plane 20261023113614000` (newest `migration_registry.txt` entry — nothing pending),
   `serverpod 20260129180959368`. Nothing destructive. No STOP condition.
2. **Fix ancestry verified** — `git merge-base --is-ancestor` under HEAD `7ace9ef`:
   `22daf08` (truncation fix commit) ✓, `b497db8` (merge) ✓. Merge touched only
   `apps/control_plane` + tests/goldens — zero server-package files.
3. **Pre-deploy bundle baseline** — pulled live `main.dart.js` (3,491,460 B) from the running
   7 h-old client; marker constants recorded for comparison.
4. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` compiled
   `lib/main.dart` for web and built `docker-client` image `089c30cac3c2` (12:07:46 EST);
   `compose build server` was **fully CACHED** (steps #7–#19) — server image `d2ab55a72f0d`
   (built 05:03Z) byte-identical because no server-compiled file changed since it was built;
   `up -d` recreated only `docker-client-1` (12:07:58Z). `docker-server-1` correctly NOT
   recreated (image digest unchanged — a restart would be a no-op, and it already carries
   the decision-surface `dba67fe` and ACP responder `fb48a35`, both merged before 05:03Z).
   `docker-postgres-1` untouched (`Up 33 hours (healthy)`); `docker-triage-seed-1` exited 0.
   No `down`, `-v`, `prune`, `--rmi`, `clean` issued; volumes untouched. Total wall ~2.5 min —
   the dispatch's ~33 min server rebuild did not occur because the cache hit is legitimate.
5. **Identity verification** (verbatim below).
6. **Untruncated-surface verification** — bundle marker diff (below).
7. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... time: 2026-11-02 05:13:34.483501Z
server-1  | runMode: staging
server-1  | Latest database migration already applied.
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/   -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>" -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, 12:09Z sample — all five rows `lastHeartbeat` 12:08:49Z):

```text
w-design-review-local   | idle | currentLoad 0
w-design-revision-local | idle | currentLoad 0
w-impl-local            | idle | currentLoad 0
w-review-local          | idle | currentLoad 0
w-triage-local          | idle | currentLoad 0
```

## Untruncated-surface verification (bundle-level)

Deployed bundle: `main.dart.js` 3,491,183 B, served by the new `docker-client-1`, byte-different
from the pre-deploy bundle (verified `cmp`). Marker diff old → new:

| marker | old bundle | new bundle | verdict |
|---|---|---|---|
| `WHAT THIS IS ABOUT \u2014 IN FULL` label const (removed `_FullContextSection`) | present (`B.VC`, `IN FULL` count 1) | **absent** (`IN FULL` count **0**) | fix deployed |
| `WHAT THIS IS ABOUT` definition-row label | 5 | 4 | row remains, uncapped per source |
| `title: ` literal (new technical-strip entry `title: ${state.workItemTitle}`) | 3 | **4** | new occurrence verified at the decision-detail code path: `if(s!=null)f.push("title: "+s)` — matches `if (state.workItemTitle != null) 'title: ${state.workItemTitle}'` |
| `ellipsis` enum string | 2 | 1 | enum still defined for the call sites that keep their pitch (TimelineTable etc.) — correct |

Source-side truth: `design_primitives.dart` DefinitionList value `Text` at HEAD carries no
`maxLines`/`overflow` (removed in `22daf08`); 8 call sites are all human-input surfaces.
The compiled bundle can no longer produce the two-line cap on those rows.

**Pending decisions exist to exercise the surface**: 5 `human_decision` rows `pending`
(engineering_review ×4, qa_waiver ×1), including long questions — e.g.
`dec-hns8okseot-1gz95y7` "Engineering review requires changes. Approve, reject, or request
rework..." (11:11Z). The WHAT THIS IS ABOUT / What Happens columns now render from the
uncapped code path. Browser-level pixel confirmation is not in this lane's tooling; the
bundle diff is the verification the dispatch asked for.

## Residuals (verbatim, non-blocking)

1. **Boot-time schema-drift WARNING** (pre-existing, unchanged):
   ```text
   WARNING: The database does not match the target database:
    - Table "design_revision" is not like the target database:
    - Missing Column "declared_owned_paths".
    - Missing Index "design_revision_approved_unique_per_work_item".
    - Missing Index "design_revision_declared_owned_paths_idx".
    - Table "product_credential" is not like the target database:
    - Missing Index "product_credential_active_repository_unique".
   ```
   `Latest database migration already applied.` precedes it. Repair decision = Manager/Human.
2. **`qa.drain.decision_refused` ×60 in the last 15 min** — same pre-existing pattern as
   prior deploys, verbatim:
   ```text
   [qa.drain.decision_refused] {workItemId: WI-feature-1791823723502264, ...,
     reason: Transition from WorkItemState.reviewApproved to
     WorkItemState.waitingForHumanDecision is not allowed, action: the item is left at
     qa_failed with no decision raised, and qa_failed has no other edge out: it cannot
     move again until somebody raises the decision by hand}
   ```
   Rate elevated vs prior report (38/25 min → 60/15 min) — more items parked at the
   `reviewApproved` edge accumulating. Flagged for Manager.
3. **`SHIPIT_PROVISION_DURABLE_WORKSPACE` still set** in the environment
   (`{"productId":"shipit-platform",...` — instruction JSON, not a credential);
   `alreadyProvisioned` path, documented-safe, operator's call to clear. Unchanged.
4. **Prior capacity wedge cleared** — exec 191 + exec 194 both closed `orphaned` via the
   F-235 zombie reclaim (03:16Z / 03:22Z, before this deploy). `running` agent_execution
   count now **0**; 5/5 workers idle; the queued `engineering_review` backlog from the
   prior report has drained (30 clean ticks / 15 min, `dispatched: 0` — nothing queued).
5. **Server container intentionally not recreated** — the ~33 min rebuild the dispatch
   anticipated did not occur: `compose build server` was fully CACHED because every
   server-compiled file is unchanged since the 05:03Z image build. The running 05:10Z
   container therefore already runs the code a rebuild would produce. Reported so the
   short duration is not read as a skipped build.

## Validation results

| Check | Status | Evidence |
|---|---|---|
| pending-migration check | pass | `20261023113614000` = newest registry entry |
| `make qa-up` | pass | client image `089c30cac3c2` built 12:07Z, recreated 12:07:58Z; server CACHED (unchanged); postgres untouched |
| `curl :8180` | pass | HTTP 200 |
| `curl :8081` title | pass | `<title>ShipIt Control Plane</title>` |
| runMode | pass | `runMode: staging` |
| 5 workers heartbeating | pass | 5/5 rows, hb ~seconds |
| HEAD contains 22daf08 + b497db8 | pass | `git merge-base --is-ancestor` both ✓ |
| untruncated bundle | pass | `IN FULL` label gone (0); `title: ` strip entry added (4th occurrence at decision-detail path); bundle differs from pre-deploy |
| pending-decision surface exercisable | pass | 5 pending rows incl. long-question engineering_review decisions |
| error signatures | pass | 0 ERROR/SEVERE/DatabaseQueryException in 15 min; 30/30 ticks `failedSections: []` |

## Evidence

```yaml
EVIDENCE_REVISION: 7ace9efdea8aa88244fccdcc429d06b772488956
BUILD_COMMAND: make qa-up
SERVE_OR_RUN_COMMAND: docker compose -f docker/compose.qa.yaml up -d
ENVIRONMENT / BASE_URL: local QA compose (project docker); api :8180, ui :8081, db localhost:5432
ARTIFACTS:
  - client image 089c30cac3c2 (built 12:07Z from HEAD 7ace9ef)
  - server image d2ab55a72f0d (built 05:03Z, CACHED-verified unchanged)
  - /tmp/qa-up-post-truncation.log (full make qa-up output)
  - /tmp/qa-main-old.dart.js / /tmp/qa-main-new.dart.js (bundle diff evidence)
```

## Cleanup confirmation

- [x] No lane-spawned processes left running.
- [x] Temporary artifacts: /tmp captures only; this report is the sole repo-dir file.
- [x] `git status` — only pre-existing untracked dispatch reports + this one; zero tracked-file modifications.
- [x] No destructive docker ops; no volumes touched; partnerhub-test-db (9090),
      control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190) never contacted.
- [x] No secret values printed (provision instruction shown as JSON keys only, truncated).

## Recommended next action

`MARK_DEPLOYED`. Route residual #2 (growing `qa_failed`-parked set at the
`reviewApproved` edge — 60 refusals/15 min) to the Manager; the transition rule it names
may need a work item.

## Structured result

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
FEATURE: redeploy QA — field-truncation fix (all human-input pages render full text)
REQUEST_ID: deploy-qa-post-truncation
CANDIDATE_ID: docker-client@089c30cac3c2 (HEAD 7ace9ef); docker-server@d2ab55a72f0d (unchanged, CACHED)
TARGET_ENVIRONMENT: STAGING
BRANCH: main
BASE_SHA: HEAD
HEAD_SHA: 7ace9efdea8aa88244fccdcc429d06b772488956

OWNED_PATHS: [] (repo files); this report.md (lane artifact)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, apps/server/migrations, apps/control_plane/lib, git history, live bundle, QA Postgres (read-only psql)]
PROHIBITED_PATHS: [all repo files (write), volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]

DURATION_SECONDS: ~420

STEPS_EXECUTED:
  - STEP_ID: preflight-migration-check
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T12:03Z
    COMPLETED_AT: 2026-11-02T12:05Z
    OUTPUT: "control_plane 20261023113614000 = newest registry entry; nothing pending; nothing destructive"
    EVIDENCE_REFS: [psql serverpod_migrations, migration_registry.txt]
  - STEP_ID: fix-ancestry + bundle-baseline
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T12:05Z
    COMPLETED_AT: 2026-11-02T12:05Z
    OUTPUT: "22daf08+b497db8 ancestors of 7ace9ef; merge touched only apps/control_plane; pre-deploy bundle 3,491,460 B captured with IN-FULL marker present"
    EVIDENCE_REFS: [git merge-base, git show --stat, /tmp/qa-main-old.dart.js]
  - STEP_ID: rebuild-and-recreate
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T12:05:45Z
    COMPLETED_AT: 2026-11-02T12:08Z
    OUTPUT: "make qa-up OK; client image 089c30cac3c2 built+recreated 12:07:58Z; server build fully CACHED (image unchanged, container correctly not recreated); postgres untouched (Up 33h)"
    EVIDENCE_REFS: [/tmp/qa-up-post-truncation.log, docker compose ps, docker images]
  - STEP_ID: identity-verification
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T12:08Z
    COMPLETED_AT: 2026-11-02T12:09Z
    OUTPUT: "runMode: staging; :8180=200; <title>ShipIt Control Plane</title>; 5/5 workers heartbeating idle"
    EVIDENCE_REFS: [server boot log, curl outputs, worker_registration query]
  - STEP_ID: untruncated-surface-verification
    STATUS: SUCCESS
    STARTED_AT: 2026-11-02T12:08Z
    COMPLETED_AT: 2026-11-02T12:09Z
    OUTPUT: "bundle differs; 'WHAT THIS IS ABOUT \u2014 IN FULL' label 1->0; 'title: ' 3->4 at decision-detail strip path; 5 pending decisions exist to render it"
    EVIDENCE_REFS: [/tmp/qa-main-new.dart.js marker counts, human_decision query]

ROLLBACK_TRIGGERED: NO
ROLLBACK_REASON: n/a
ROLLBACK_RESULT: n/a

POST_DEPLOYMENT_VALIDATION:
  HEALTH_CHECKS: PASS
  SYNTHETIC_TRANSACTIONS: PASS (:8180=200; :8081 title verified; 30 clean ticks/15 min)
  KEY_METRICS: PASS (5/5 workers hb ~seconds; 0 running executions; wedge cleared)
  ERROR_RATES: PASS (0 ERROR/SEVERE/DatabaseQueryException in 15 min)
  MOBILE_COMPATIBILITY: NOT_APPLICABLE

OVERALL_VERDICT: DEPLOYMENT_SUCCESSFUL

DISCOVERIES:
  - RUNTIME_DISCOVERY: qa.drain.decision_refused rate is growing with the parked
    qa_failed set (60 refusals/15 min vs 38/25 min prior deploy) — the reviewApproved ->
    waitingForHumanDecision edge refusal accumulates items; flagged for Manager.
  - PROJECT_FACT: `compose build server` is fully cache-hit for client-only merges —
    qa-up takes ~2.5 min (not ~33 min) when only apps/control_plane changed, and
    `up -d` correctly leaves the server container running since the image digest is
    identical. Expect this asymmetry; a short deploy is not a skipped build.

KNOWLEDGE_PERSISTED:
  - report.md at docs/engineering/dispatch/tasks/deploy-qa-post-truncation/report.md

BLOCKERS: none for the deploy. Residual #2 (growing qa_failed-parked set) routed to Manager.
```

RESULT: DEPLOYMENT_SUCCESSFUL
