# Dispatch — deploy-qa-decision-fix

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-decision-fix
TASK_TYPE: deploy
FEATURE: redeploy QA at merged HEAD — decision-card bug fix (server + client)
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: 2f266b3
OWNED_PATHS: [] (operational lane — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile, docs/deployment/local-qa.md]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate"
Merge-tier gate: server side ran +319 green at the decision-card merge; the client merge is
client-only (zero server/shared-contract files) — do NOT re-run it.

## Required actions

1. Rebuild server+client, restart QA at HEAD via `make qa-up`; check pending migrations first;
   no destructive commands.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the bug fix** (acceptance): the reported symptom was "Review and decide" on a
   "Waiting for your approval" card → "We could not open this decision" at
   `/needs-you/dec-hn7h7daum6-2atjhe`. Post-deploy verify: (a) `pendingDecisions` for the
   blocked item `defect-DEF-1791685264570406` now surfaces `dec-hn9zf6jgzn-158lz0o` (pending),
   NOT `dec-hn7h7daum6-2atjhe` (cancelled) — check via the workItemActionEndpoints/home
   endpoints response or server logs/psql confirming which decisionId the card surfaces;
   (b) the ?wi= param now carries `defect-DEF-1791685264570406` on the Home gate card deep link
   (check the built client's route generation or server-side decision view).
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
evidence that the surfaced decisionId is now the pending one.
