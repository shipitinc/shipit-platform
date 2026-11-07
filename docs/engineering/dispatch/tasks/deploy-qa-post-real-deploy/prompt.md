# Dispatch — deploy-qa-post-real-deploy

```yaml
TASK_ID: deploy-qa-post-real-deploy
TASK_TYPE: deploy
FEATURE: redeploy QA — real deploy execution live (deployment_approval -> land the produced commit)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~8-33min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify — `deploy_landing.dart` + the `resolveHumanDecision` dispatch are
in the built artifact; if a `deploymentApproval` pending exists, approving one lands the
produced commit into `repositoryPath` and stamps `deployedCommit` on the item; (4) residuals
verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
