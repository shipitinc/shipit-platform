# Dispatch — deploy-qa-post-contract-instr

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-contract-instr
TASK_TYPE: deploy
FEATURE: redeploy QA — missing-artifact fix + contract-instruction fix live
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: HEAD
OWNED_PATHS: [] (operational — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate."

## Required actions

1. `make qa-up` — rebuild + recreate at current HEAD (carries the contract-instruction fix
   `eb58bf8` + the missing-artifact fix `94208c5`; server rebuild ~33min expected, cache may
   shorten); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify both fixes** — (a) the deployed artifact carries `ProducerRoleScopedGate` +
   the new instruction wording ("informational only", "do not look for it") and the denial-aware
   missing-artifact reason; (b) the NEXT implement run's instruction no longer sends the agent
   hunting the DB-resident contract (the implementation_ready items re-triage on the paid tier
   and should now produce commits instead of missing-artifact failures).
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
