# Dispatch — integrate-deploy-main-reroute

```yaml
TASK_ID: integrate-deploy-main-reroute
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/deploy-main-reland-reroute (HEAD d6e995d, corrected)
WORKTREE: /private/tmp/shipit-feat-deploy-main
BRANCH: feat/deploy-main-reland-reroute
BASE_SHA: aa83787
HEAD_SHA_UNDER_REVIEW: d6e995dca86cbee075451ccea812a8e8aa51b5ff
REVIEW_PROVENANCE: focused-reviewer APPROVE_CORRECTIONS on d6e995d (a3a6bc5 + correction; gates green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`aa83787` — re-land merge d1de65a + ledger commits): `git fetch`/`merge-base`/dry-run merge of
`d6e995d` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (the re-land merge
extended `deploy_landing.dart` + `work_item_action_endpoints.dart` — this change touches the same
files plus `packages/workflow_engine` + `apps/control_plane/lib/shared/`; check for semantic
overlap); verify provenance (the corrected HEAD is what's merged); re-run gates on the merged
tree if the base diverged — `dart format`, `dart analyze` (apps/server + workflow_engine +
control_plane), `dart run tool/run_unit_tests.dart` (apps/server), `dart test`
(packages/workflow_engine), `flutter test` (apps/control_plane). Report `RESULT:
MERGE_APPROVED` / `BLOCKED`.
