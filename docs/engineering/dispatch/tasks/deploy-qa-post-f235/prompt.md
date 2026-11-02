# Dispatch — deploy-qa-post-f235

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-f235
TASK_TYPE: deploy
FEATURE: redeploy QA — F-235 (agent_execution retire) + auto-escalation live
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

1. Restore `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2` in `docker/.env` (a temporary wedge-unblock left
   at 3 by the prior deploy lane — the zombies have since reclaimed, so restore the default).
2. `make qa-up` — rebuild + recreate at current HEAD (carries F-235 + auto-escalation + env wiring);
   check pending migrations first.
3. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
4. **Verify the fixes land** — confirm the new image is at a HEAD containing `50724a0` (F-235) and
   `28e89f9` (auto-escalation); the queued triage jobs dispatch on the paid tier (model_execution
   shows a non-free model, tokens > 0); no zombie rows accumulate.
5. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
