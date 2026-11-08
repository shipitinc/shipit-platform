# Subtask Report — deploy-qa-post-operator-actions

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-operator-actions
TASK_TYPE: deploy
FEATURE: redeploy QA — operator actions live (qa_passed->deploy + stranded agent_executing->reclaim)
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: 4eb53c4
HEAD_SHA: 4eb53c4
COMMITTED: NO
```

## Ownership

- OWNED_PATHS: none — zero repo file edits; this report is the only artifact.
- READ_ONLY_PATHS: Makefile, docker/compose.qa.yaml, docker/Dockerfile.server,
  apps/server, apps/control_plane, docs/engineering/**.
- PROHIBITED_PATHS: all repo files, volumes/data, partnerhub-test-db (9090),
  control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190).

## Pre-deployment migration check

`git log --name-only f65eb4b^..4eb53c4` — the merge touches **zero** migration
files (dart/yaml/docs only). DB already at latest:

```text
 control_plane | 20261023113614000 | 2026-10-26 12:15:26.351351
 serverpod     | 20260129180959368 | 2026-10-26 12:15:26.351351
```

Post-boot confirms: `Latest database migration already applied.` No
SAFE/RISKY/DESTRUCTIVE steps existed — nothing to classify or escalate.

## Steps executed

1. `make qa-up` — started 03:37:57Z, finished 04:08Z (~30 min wall; client
   Flutter compile ~11 min, server image `build_runner` ran fresh ~8 min
   (faster than the 33 min expectation — warm layer cache), then
   `up -d` recreated `docker-server-1` and `docker-client-1`.
   `docker-postgres-1` untouched (Up 4 days). New images:
   `docker-server sha256:ba900c548cd8…` (04:07:30Z),
   `docker-client sha256:550247c40b22…` (03:51:28Z).
2. Identity verification — PASS (verbatim below).
3. Operator-action verification — PASS (verbatim below).
4. Residuals — verbatim below.

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... on "linux_arm64", time: 2026-11-05 04:10:48.590105Z
server-1  | runMode: staging
server-1  | SERVERPOD initialized, time: 2026-11-05 04:10:48.912784Z
server-1  | Latest database migration already applied.
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/     -> 200
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/ -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>"   -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, sampled 04:13:56Z — heartbeats 04:13:48Z, ~8s fresh):

```text
w-design-review-local   | idle | currentLoad 0 | 2026-11-05 04:13:48.561867
w-design-revision-local | idle | currentLoad 0 | 2026-11-05 04:13:48.559962
w-impl-local            | idle | currentLoad 0 | 2026-11-05 04:13:48.558343
w-review-local          | idle | currentLoad 0 | 2026-11-05 04:13:48.556084
w-triage-local          | idle | currentLoad 0 | 2026-11-05 04:13:48.536338
```

Boot composition: `workerRegistration: {registered: [w-triage-local,
w-review-local, w-impl-local, w-design-revision-local, w-design-review-local],
registeredCount: 5, failed: {}, previouslyStale: []}`.

## Operator-action verification (verbatim)

Baseline captured on the OLD image (built 2026-11-03, predates merge
f65eb4b 2026-11-05T03:36Z): `actionContext` returned `actions: []` for every
probed item — including the stranded one.

Post-deploy, `POST http://localhost:8180/workItemActionEndpoints/actionContext`:

**Stranded `agent_executing`** — `defect-DEF-1791685024220546` (15 jobs all
failed/succeeded/cancelled — none active; 14 agent_executions all terminal:
7 completed, 4 failed, 3 interrupted):

```json
"state": "agent_executing",
"actions": [
  {
    "__className__": "WorkItemActionView",
    "action": "reclaim",
    "toState": "agent_failed",
    "confirmRequired": true,
    "destructive": false,
    "attemptLimit": 0
  }
]
```

**`qa_passed` → `deploy`** — all 12 items in state `qa_passed` return the
deploy action (each carries a deployable produced artifact). Representative
`WI-feature-1791823723502264`:

```json
"state": "qa_passed",
"actions": [
  {
    "__className__": "WorkItemActionView",
    "action": "deploy",
    "toState": "waiting_for_human_decision",
    "confirmRequired": true,
    "destructive": false,
    "attemptLimit": 0
  }
]
```

(12/12 scanned: WI-feature-1791823723502264, DEF-fresh-test, DEF-f223-test,
defect-DEF-1791684804452198, -5264570406, -5722309971, -5924503981,
-6085546076, -6357139031, -6704991884,
design-remediation-DEF-1791685264570406, design-remediation-DEF-1791686085546076.)

**UI panel in built bundle** — served `main.dart.js` (3,497,660 bytes, fresh
client image) contains the new panel copy and endpoint wiring:

```text
"It passed its checks"                    -> 1   (deployPanelHeading)
"It says it is running — nothing is"      -> 1   (reclaimPanelHeading)
"Move it forward"                         -> 2   (deployActionLabel)
"Hand it back"                            -> 2   (reclaimActionLabel)
"nothing is deployed without you"         -> 1   (deployPanelExplanation)
actionContext x7, workItemActionEndpoints x6, advanceToDeploy x1,
reclaimStrandedExecution x1
```

## Residuals (verbatim)

1. Boot-time schema-analyzer WARNING (staging keeps it non-fatal; identical
   drift carried by the prior deploy — `declared_owned_paths` column and three
   indexes missing; real, non-blocking):

```text
WARNING: The database does not match the target database:
 - Table "design_revision" is not like the target database:
 - Missing Column "declared_owned_paths".
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Missing Index "design_revision_declared_owned_paths_idx".
 - Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
Hint: Did you forget to run `serverpod generate`, apply the migrations (--apply-migrations), or run a repair migration (--apply-repair-migration)?
```

2. `[durable_workspace.provision.requested]` then `.refused`
   (`WORKSPACE_ALREADY_PROVISIONED`) then `.already_provisioned` — satisfied
   outcome; notes verbatim "SHIPIT_PROVISION_DURABLE_WORKSPACE MAY NOW BE
   CLEARED from the deployment environment". Informational, recurs each boot
   while the instruction stays set.
3. `[work_entry.sweep.disabled]` — documented design-revision.md §15 gate
   (P-2/P-5 unproven); printed on every start, not a fault.
4. Client build: "72 packages have newer versions incompatible with
   dependency constraints" (informational `flutter pub get` output, unchanged
   from prior deploys).
5. No `TICK_OVERLAP_DROPPED` or `completed_late` events this boot — all
   observed ticks `ran: true, failedSections: []`. First API availability was
   ~2.5 min after container start (04:08:12Z up → 04:10:48Z initialized);
   during boot the container produced no stdout for ~2.5 min — silent
   pre-initialization, resolved on its own.

## Constraints honored

- Zero repo file edits (only this untracked report artifact).
- Compose commands only against `docker/compose.qa.yaml`, project `docker`.
- No `down`, `-v`, `prune`, `--rmi`, `clean`; no volume touched; postgres
  container untouched (Up 4 days).
- Never approached `partnerhub-test-db` (9090), `control_plane-postgres_test-1`
  (9099), `server-postgres_test-1` (9190) — all verified still running.
- No secret values printed; `docker/.env` never read for display.

## Discoveries

- `RUNTIME_DISCOVERY`: `dart run build_runner build` inside the server image
  ran ~8 min this build (vs ~33 min expectation) — BuildKit layer cache of the
  `pub get` stage plus warm builder caches shorten it materially; the ~33 min
  figure is the cold path.
- `RUNTIME_DISCOVERY`: first API readiness lags container start ~2.5 min and
  the container emits **zero** stdout during that window (silent pre-init);
  a deploy lane should poll `:8180` rather than read `docker logs` to detect
  readiness — logs appearing at all is itself the readiness signal.

RESULT: DEPLOYMENT_SUCCESSFUL
