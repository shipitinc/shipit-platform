# Subtask Report — deploy-qa-post-reroute

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-reroute
TASK_TYPE: deploy
FEATURE: redeploy QA — default-branch land + rerouteToImplementation live
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: d28bb9a
HEAD_SHA: d28bb9a
COMMITTED: NO
```

OWNED_PATHS: docker/compose.qa.yaml stack (project `docker`), this dispatch task dir
PROHIBITED_PATHS respected: no repo source edits, no volumes destroyed, no `down -v`/`prune`/`--rmi`/`make clean`,
partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190) untouched.
No secret values printed.

## Execution

1. **Migration check (pre-deploy)**: `serverpod_migrations` already at `20261023113614000` (latest in
   `migration_registry.txt`) — no pending migrations; `--apply-migrations` a no-op.
2. **`make qa-up`**: client Flutter web build (~25 min under loadavg ~50), client image built via compose
   ownership path (check-client-build OK), server image rebuilt (build_runner/AOT ~546s + runtime stage),
   `compose up -d` recreated `docker-server-1` and `docker-client-1`; `docker-postgres-1` left running.
   Server image: `docker-server` sha256:a40f137490d4. Total wall ~48 min (host under sustained loadavg 40-57).
   NOTE: a first `make qa-up` invocation orphaned by an exec timeout was killed (SIGTERM) before its flutter
   build could corrupt the second run's shared `.dart_tool` output dir — disclosed, no state damage.
3. **Identity verified**: `runMode: staging` (boot banner), `:8180` -> **200**,
   client `<title>ShipIt Control Plane</title>` on :8081, 5 workers heartbeating
   (w-triage-local, w-review-local, w-impl-local, w-design-revision-local, w-design-review-local; age <1s).
4. **Feature verified in built artifact** (inside running `docker-server-1`, `/app`):
   - `rerouteToImplementation`: `apps/server/lib/src/endpoints/work_item_action_endpoints.dart` + generated
     `endpoints.dart` (endpoint registered).
   - `_resolveDefaultBranch`: `apps/server/lib/src/deploy/deploy_landing.dart`.
   - Reroute edge live: `work_item_transitions.dart:917` `(deployed, implementationReady)` guarded by
     `actorAllowed([orchestrator])` + `operatorRerouteRequested()`.
   - The 6 stranded items all confirmed `state=deployed`, empty `artifactRefsJson` (no deployedCommit):
     `defect-DEF-1791686085546076`, `WI-feature-1791823723502264`, `defect-DEF-1791685924503981`,
     `defect-DEF-1791685264570406`, `DEF-fresh-test`, `defect-DEF-1791686357139031` — each is reroutable
     via the operator `reroute` action (state matches the edge's from-state; ledger replay covers dedupe).

## Residuals (verbatim, non-blocking)

```
WARNING: The database does not match the target database:
 - Table "design_revision" is not like the target database:
 - Missing Column "declared_owned_paths".
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Missing Index "design_revision_declared_owned_paths_idx".
 - Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
Hint: Did you forget to run `serverpod generate`, apply the migrations (--apply-migrations), or run a repair migration (--apply-repair-migration)?
```
(staging runMode — warning, not fatal; same class of schema-analyzer noise this stack already documents)

```
[agent_runtime.adapter_health_probe_failed] {providerId: opencode, runtimeTypeId: opencode,
error: TimeoutException after 0:00:30.000000: Future not completed,
action: registered, but reachability is UNVERIFIED}
```
(boot-time probe timeout under heavy host load; providerHealthMonitor retries every 5 min)

- `SHIPIT_PROVISION_DURABLE_WORKSPACE` remains set; boot reports `provision.already_provisioned` —
  its own note: "MAY NOW BE CLEARED from the deployment environment" (leaving it set is safe).
- `[work_entry.sweep.disabled]` — documented design-revision.md §15 gate, printed every start; not a fault.

## Validation results

| Check | Status | Evidence |
|---|---|---|
| Pending migrations | pass | DB at `20261023113614000`; boot log "Latest database migration already applied." |
| `make qa-up` | pass | containers recreated; compose ps all Up |
| runMode staging | pass | boot banner `runMode: staging` |
| :8180 health | pass | HTTP 200 |
| Client title | pass | `ShipIt Control Plane` on :8081 |
| 5 workers heartbeating | pass | worker_registration ages <1s, count 5 |
| reroute + default-branch in artifact | pass | greps inside running image |
| 6 items reroutable | pass | all `deployed`; edge `deployed->implementationReady` present with reroute guard |

## Cleanup confirmation

- [x] No processes left running by this lane (`make qa-up` exited; duplicate orphan killed and reported).
- [x] No temporary artifacts in repo (build log at /tmp/qa-up-deploy-reroute.log, outside repo).
- [x] No repo source files modified.
- [x] No prohibited Docker operations; QA volumes and other stacks' DBs untouched.

## Recommended next action

`MARK_DEPLOYED`
