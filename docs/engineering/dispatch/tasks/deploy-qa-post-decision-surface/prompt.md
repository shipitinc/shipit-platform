# Dispatch — deploy-qa-post-decision-surface

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-decision-surface
TASK_TYPE: deploy
FEATURE: redeploy QA — decision-detail surface (dba67fe) + ACP permission responder (fb48a35) live
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries dba67fe decision-surface +
   fb48a35 ACP-responder); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the decision surface** — on a pending engineering-review decision (e.g.
   `dec-hnrsbbnk2c-d96769` or a fresh one), confirm the detail page now renders the verdict
   badge + findings + full context + real option consequences (not the truncated description).
   `curl`/inspect the detail response's metadataJson to confirm it carries engineeringReviewResult.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
