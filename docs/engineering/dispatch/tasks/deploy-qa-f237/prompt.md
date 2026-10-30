# Dispatch — deploy-qa-f237

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-f237
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — activates F-237 detached dispatch + F-232
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: adda3ee
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, docs/deployment/local-qa.md]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate" (2026-10-30, repeated directive)

## Required actions, in order

1. `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` at HEAD — the
   owed merge-tier gate for F-237 (`adda3ee`) and F-232 (`b2148d9`). STOP and report if red.
2. Rebuild server+client, restart QA stack at HEAD (`make qa-up`); no destructive commands.
   Check pending migrations first; STOP+escalate if any look destructive.
3. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   all 5 workers registered/heartbeating.
4. **Verify the F-237 effect** (this deploy's acceptance): over ~10 min monitor
   `scheduler_event` + `job`/`worker_execution` — EXPECT: ticks continue DURING in-flight
   executions (enqueues/drains happen while a job is `running`); more than one job can be
   `running` simultaneously up to the cap; `job_dispatched` no longer waits for prior
   executions' completion. Check `implementation.deferred.*`/deferral lines in
   `docker compose -f docker/compose.qa.yaml logs server` verbatim. Also confirm the two
   test items' design_revision job states and impl-queue drain.
5. Report residual blockages verbatim.

## Report

`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
gate output, image digests, identity evidence, F-237 effect evidence (or its absence),
and residual-blockage list.
