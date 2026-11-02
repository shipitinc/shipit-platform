# Dispatch — deploy-qa-post-qa-gates

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-qa-gates
TASK_TYPE: deploy
FEATURE: redeploy QA — producer-scoped QA gate live (feature items can pass contracts)
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries the gate fix `c58352a`; server
   rebuild ~33min expected); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the gate fix** — on a feature item's contract evaluation the
   `intake-structured-result-admitted` gate now evaluates `not_applicable` for a non-triage
   producer (the four implementer gates judge it instead); a defect item's triage contract
   still applies the strict gate. The two parked waiver items can now reach qaPassed honestly
   on re-evaluation (or their pending waiver resolves on its own terms).
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
