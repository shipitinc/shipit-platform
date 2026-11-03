# Dispatch — deploy-qa-post-infra-decision

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-infra-decision
TASK_TYPE: deploy
FEATURE: redeploy QA — infra-decision resolve fix live (system:provider-health decisions resolvable)
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries the infra-decision fix `ccb6538`;
   server rebuild ~33min, cache may shorten); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the fix** — `POST /workflowEndpoints/resolveDecision` with a `system:provider-health`
   decisionId (e.g. `hd-provider-openrouter-1793568760661570`, choice `acknowledge`, decider
   `operator`, an operator-sig DecisionSignature) no longer 500s — it resolves and returns a
   valid view. Do NOT resolve the whole stack — verify ONE resolves cleanly and report.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
