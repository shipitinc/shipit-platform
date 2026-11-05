# Dispatch — deploy-qa-post-auto-deploy

```yaml
TASK_ID: deploy-qa-post-auto-deploy
TASK_TYPE: deploy
FEATURE: redeploy QA — runDeployGateSweep live (qa_passed -> deploying + deploymentApproval -> Needs You)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~8-33min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify the sweep — after a tick, `qa_passed` items have advanced to
`waiting_for_human_decision` with a `deploymentApproval` decision pending, and `pendingDecisions`
(Needs You) surfaces them; (4) residuals verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
