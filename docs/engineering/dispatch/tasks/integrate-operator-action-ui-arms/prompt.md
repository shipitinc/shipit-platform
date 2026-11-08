# Dispatch — integrate-operator-action-ui-arms

```yaml
TASK_ID: integrate-operator-action-ui-arms
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/operator-action-ui-arms (HEAD 79675d7)
WORKTREE: /private/tmp/shipit-feat-ui-arms
BRANCH: feat/operator-action-ui-arms
BASE_SHA: d28bb9a
HEAD_SHA_UNDER_REVIEW: 79675d79ceb8c9961fe688a44a166d3727d74f93
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on 79675d7 (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`d28bb9a` — deploy-main merge + ledger commits): `git fetch`/`merge-base`/dry-run merge of
`79675d7` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (main advanced
in `work_item_action_endpoints.dart`, `deploy_landing.dart`, `apps/control_plane/lib/shared/`,
`packages/workflow_engine` via the deploy-main merge — this change touches
`work_item_action_endpoints.dart` + `apps/control_plane/lib/features/run_detail/**` +
`lib/data/`; check for semantic overlap); verify provenance; re-run gates on the merged tree
if the base diverged — `dart format`, `dart analyze` (apps/server + control_plane),
`dart run tool/run_unit_tests.dart` (apps/server), `flutter test` (apps/control_plane).
Report `RESULT: MERGE_APPROVED` / `BLOCKED`.
