# Dispatch — deploy-qa-post-ui-arms

```yaml
TASK_ID: deploy-qa-post-ui-arms
TASK_TYPE: deploy
FEATURE: redeploy QA — reland + reroute visible in actionContext/UI (F-260 + F-262)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~2-45min/cache); (2) verify identity (runMode staging, :8180 200,
title, 5 workers); (3) verify — `actionContext` on a `deployed` item missing deployedCommit
offers [reland, reroute], on a stamped one offers [reroute]; the UI panel code is in the built
bundle; (4) residuals verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
