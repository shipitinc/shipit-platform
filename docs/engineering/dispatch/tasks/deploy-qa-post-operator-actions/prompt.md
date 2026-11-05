# Dispatch — deploy-qa-post-operator-actions

```yaml
TASK_ID: deploy-qa-post-operator-actions
TASK_TYPE: deploy
FEATURE: redeploy QA — operator actions live (qa_passed->deploy + stranded agent_executing->reclaim)
WORKTREE: canonical /Users/alkebut/air/shipit-platform (no repo edits)
BRANCH: main
BASE_SHA: HEAD
PROHIBITED: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
```

Standing authorization: "deploy the changes, monitor, remediate." (1) `make qa-up` (migration
check first, server rebuild ~33min/cache); (2) verify identity (runMode staging, :8180 200,
title ShipIt Control Plane, 5 workers); (3) verify the actions — `actionContext` on a `qa_passed`
item returns a `deploy` action, on a stranded `agent_executing` a `reclaim` action; the UI panel
code is in the built bundle. (4) residuals verbatim. `RESULT: DEPLOYMENT_SUCCESSFUL`/`FAILED`/`PARTIAL`.
