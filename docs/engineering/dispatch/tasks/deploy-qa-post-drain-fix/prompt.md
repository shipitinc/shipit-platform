# Dispatch — deploy-qa-post-drain-fix

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-drain-fix
TASK_TYPE: deploy
FEATURE: redeploy QA — drain-loop fix live (decision_refused noise stops; parked items reach a decision)
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries the drain fix `158d831`; server
   rebuild ~33min expected); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the fix** — `qa.drain.decision_refused` count drops to ~0/tick (was ~60/15min); the
   two parked items (`WI-feature-1791823723502264`, `defect-DEF-1791685024220546`) get their
   waiver decisions raised → `waiting_for_human_decision` (the qaFailed candidate arm reaches
   them). Report the drain's `qa.drain.completed` counts after the fix lands.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
