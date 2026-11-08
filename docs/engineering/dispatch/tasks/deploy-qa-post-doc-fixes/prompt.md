# Dispatch — deploy-qa-post-doc-fixes

```yaml
TASK_ID: deploy-qa-post-doc-fixes
TASK_TYPE: deploy
FEATURE: redeploy QA — gen-doc + store-doc + jobid doc corrections live (F-255/263/265 closed)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~2-45min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify the corrected docs are in the built artifact (six-token vocabulary
+ honest jobId doc in generated/database/operator_action.dart; corrected spy.yaml); (4) residuals
verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
