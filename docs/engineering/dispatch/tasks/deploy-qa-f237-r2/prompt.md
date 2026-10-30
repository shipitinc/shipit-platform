# Dispatch — deploy-qa-f237-r2

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-f237-r2
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — activates F-237 detached dispatch + F-232 (gate now paid)
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: 35ababa
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, docs/deployment/local-qa.md]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate" (2026-10-30, repeated)

## Note on the merge-tier gate — already PAID
`make test-integration` was run green (+319, All tests passed!) TWICE on the code this merge
contains: by the focused-reviewer AND accepted as evidence by the integrator at `cb5f76f`; the
merge `20703a7` is bit-identical outside `docs/`. Do NOT re-run it — proceed to rebuild.

## Required actions, in order

1. Rebuild server+client, restart QA stack at HEAD (`make qa-up`); no destructive commands.
   Check pending migrations first; STOP+escalate if any look destructive.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   all 5 workers registered/heartbeating.
3. **Verify the F-237 effect** (acceptance): over ~10 min — ticks CONTINUE during in-flight
   executions (enqueues/drains while a job is `running`); more than one job may be `running`
   concurrently up to the cap; `job_dispatched` no longer waits for prior completions;
   `TICK_OVERLAP_DROPPED` should NOT accumulate while an execution runs. Evidence via read-only
   psql (localhost:5432 shipit/shipit) + `docker compose -f docker/compose.qa.yaml logs server`.
   Check the two test items' design_revision job states + impl-queue drain.
4. Report residual blockages verbatim (esp. F-238-class errors: "Session or transaction has
   already finished" or transaction-slot collisions in server logs — detached dispatch is now
   live and that race is timing-dependent).

## Report

`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
identity + F-237-effect evidence and residuals.
