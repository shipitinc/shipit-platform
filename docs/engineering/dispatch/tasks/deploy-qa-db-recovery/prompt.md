# Dispatch — deploy-qa-db-recovery

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-db-recovery
TASK_TYPE: deploy
FEATURE: QA Postgres stuck in recovery mode — diagnose + recover without data loss
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout (no repo file writes)
BRANCH: main
BASE_SHA: HEAD
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate"

## Situation (verbatim evidence)
QA Postgres has been in recovery ~15+ min as of ~13:50 EDT 2026-10-31:
`FATAL: the database system is in recovery mode` (rejecting connections);
server :8180 returns 000 (refuses — DB down); client :8081 serves static only.
`docker-postgres-1` was "Up 7 days (healthy)" before the last `make qa-up`
recreated server+client only — postgres was NOT recreated. Likely unclean
shutdown/crash mid-workload.

## Task

1. **Diagnose**: `docker logs docker-postgres-1 --tail 200` (and the compose
   postgres container logs) — is it replaying WAL (progressing) or stuck?
   Check `docker inspect` restart policy / last exit. Check disk space
   (`df -h` on the volume host path — a full volume is a classic cause).
2. **Recover — data-preserving only**: options in order:
   (a) if WAL replay is just slow, wait and re-verify it accepts connections;
   (b) a clean `docker compose -f docker/compose.qa.yaml restart postgres`
       ONLY if the container is hung — first confirm recovery isn't
       progressing in the log (a restart mid-replay can extend corruption);
   (c) if the container is dead/crash-looping, report the last error verbatim.
   **NEVER** `down -v`, volume rm, prune, or delete the data directory —
   the QA DB holds human workflow state; this is a data-preserving operation.
3. **Verify**: postgres accepts connections (`pg_isready`), server :8180
   responds 200, client :8081 serves the app, workers heartbeat again.
4. Report root cause (from logs, verbatim) + what you did + current state.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`
with the verbatim log root-cause and post-recovery health checks.
