# Dispatch — deploy-qa-post-producer-res

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-post-producer-res
TASK_TYPE: deploy
FEATURE: redeploy QA — producer-resolution fix live (qa-triage contracts evaluate the triage result)
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

1. `make qa-up` — rebuild + recreate at current HEAD (carries the producer-resolution fix
   `1c37bf3`; server rebuild ~33min, cache may shorten); check pending migrations first.
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating.
3. **Verify the fix** — the deployed artifact carries the `requiredRole` scope
   (ProducerResolution.requiredRole + producerRoleForQaContractId); on the next defect item's
   qa-triage evaluation the contract resolves the TRIAGE execution's result, not an
   implementer's — the triage gates see the triage-shaped structuredResult (classification +
   evidenceUsed) and can pass honestly. The reworked defect items' re-evaluations should no
   longer fail "cites no evidence" on the wrong producer.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`.
