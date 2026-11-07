# Dispatch — deploy-qa-post-reland

```yaml
TASK_ID: deploy-qa-post-reland
TASK_TYPE: deploy
FEATURE: redeploy QA — re-land path live (relandDeployedWorkItem for label-only deployed items)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~2-33min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify — `relandDeployedWorkItem` + `deployRelandIsOwed` are in the built
artifact; the 13 label-only `deployed` items (deployedCommit NULL) are re-landable; (4) residuals
verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
