# Dispatch — deploy-qa-redeploy-head

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-redeploy-head
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD (F-226 + F-227 fixes)
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: ced90dd
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS:
  - docker/compose.qa.yaml
  - Makefile
  - docs/deployment/local-qa.md
  - docs/engineering/FOLLOW_UPS.md
PROHIBITED_PATHS:
  - every repository file (no code edits)
  - volumes, `down -v`, `prune`, `--rmi`, `make clean`
  - partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)
ACCEPTANCE_CRITERIA: see below
ROUTING_CLASS: STANDARD
```

## Authorization (human, verbatim): "deploy the changes, monitor, remediate"

## Required actions, in order

1. **Owed merge-tier gate first.** `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw
   make test-integration` at the canonical checkout HEAD (`ced90dd`) — it is the declared
   merge/release gate owed by BOTH merged fixes (`eeb9c97` dedupe self-heal, `a661aae`
   worker-lease bound). It creates and removes its own disposable Postgres (the only
   sanctioned docker usage besides the QA stack). Report the pass/fail count VERBATIM.
   If it fails, STOP — report the failures; do not deploy on a red gate.
2. **Rebuild + restart the QA stack at HEAD**: rebuild `server` and `client` images
   (`docker compose -f docker/compose.qa.yaml build` or `make qa-up` — read the Makefile
   target first) and bring them up/restart. No `down -v`, `prune`, `--rmi`, `volume rm`,
   `make clean`. Check for pending migrations before restart; STOP + escalate if any look
   destructive (DROP/TRUNCATE).
3. **Verify by identity** (never bare status): `runMode: staging` in boot output;
   `curl http://localhost:8180/` responds; `curl http://localhost:8081/` returns
   `<title>ShipIt Control Plane</title>`; workers registered and heartbeating.
4. **Confirm the lanes are healthy post-deploy** (psql to localhost:5432 shipit/shipit,
   read-only SELECTs): the two `design_revision` jobs' states; the 7 `implement_feature`
   jobs' states; `worker_registration` statuses; any new `job_deferred`/`workerBusy`
   events after deploy; `agentExecuting` executions bounded by their budgets.
5. **Monitor through a few ticks (~5 min)** and report residual blockages verbatim
   (deferral reasons from `docker compose -f docker/compose.qa.yaml logs server` — the
   `implementation.deferred.*` / `design.*` lines).

## Report

`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` per
subtask-report.md with verbatim gate output, image digests, identity evidence, and the
residual-blockage list.
