# Dispatch — deploy-qa-f241-f242

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-f241-f242
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — F-241 CAS-transient + F-242 contract-gate live
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: 30cf939
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate"
Merge-tier gate PAID on both merges (integrator ran +319 each).

## Required actions

1. Rebuild server+client, restart QA at HEAD via `make qa-up`; check pending migrations first;
   no destructive commands. NOTE: the shared Docker VM disk was at ~95% after the earlier ENOSPC
   recovery — check `df` on /var/lib/docker and free dangling images ONLY if needed to make room
   (reproducible artifacts; disclose anything removed; never volumes/data).
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the fixes (acceptance):**
   (a) F-241: watch the next ~10 min of retried triage jobs (the 10 retried items) — any
       `Concurrent modification` error should now classify `executionInterrupted`/transient
       (re-queued via `jobRetryScheduled`), NOT `executionFailed`/permanent. Check
       `scheduler_event` + job states for a CAS loss landing transient instead of terminal.
   (b) F-242: `DEF-fresh-test`/`DEF-f223-test` (no qaContractId) should now DEFER —
       `triage.deferred.qa_contract_missing`/`implementation.deferred.qa_contract_missing` events,
       jobs `queued`/`blockedArtifactMissing`, NOT dispatched-and-failed at agentCompleted.
4. Report residuals verbatim + whether the retried items are now clearing vs still churning.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
evidence for both fix verifications.
