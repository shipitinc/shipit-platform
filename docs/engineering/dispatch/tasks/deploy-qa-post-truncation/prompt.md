# Dispatch — deploy-qa-post-truncation

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-truncation
TASK_TYPE: deploy
FEATURE: redeploy QA — field-truncation fix (all human-input pages render full text)
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries the field-truncation fix +
   decision-surface + ACP responder); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the untruncated surface** — the deployed main.dart.js no longer caps DefinitionList
   values (grep the bundle for the untruncated rendering / the truncated cap); on a pending
   decision the WHAT THIS IS ABOUT + What Happens columns render full text.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
