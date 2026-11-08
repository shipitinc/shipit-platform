# Dispatch — deploy-qa-post-deploy-push

```yaml
TASK_ID: deploy-qa-post-deploy-push
TASK_TYPE: deploy
FEATURE: redeploy QA — deploy landing push-remote live (F-258)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~2-45min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify deploy_push.dart is in the built artifact and the
`deployedRemote` stamp path is wired (`grep` the image for the transport/push); (4) residuals
verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
