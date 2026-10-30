# Dispatch — deploy-qa-f238

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-f238
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — activates F-238 zone-scoped tx binding
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: 42d3f81
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, docs/deployment/local-qa.md]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate" (2026-10-30, repeated)
Merge-tier gate already PAID — `make test-integration` ran on the merged tree itself (+318-1, sole
failure unrelated dogfood timeout). Do NOT re-run it.

## Required actions, in order

1. Rebuild server+client, restart QA at HEAD via `make qa-up`; check pending migrations first;
   no destructive commands.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   all 5 workers registered/heartbeating.
3. **Verify F-238 fix** (acceptance): over ~15 min of monitoring, confirm ZERO occurrences of
   `Session or transaction has already finished` / `DatabaseQueryException` at the 3 prior sites
   (design.tick, implementation.tick, review.settled-redrive/listJobs) in
   `docker compose -f docker/compose.qa.yaml logs server` — versus 3 hits observed pre-deploy
   under detached dispatch. Also re-confirm the F-237 concurrency effect (ticks continuing during
   in-flight executions, concurrent dispatches at cap). Check job/worker_execution read-only via
   psql (localhost:5432 shipit/shipit).
4. Report residuals verbatim.

## Report

`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
identity + race-error evidence (presence or ABSENCE at the 3 sites) and residuals.
