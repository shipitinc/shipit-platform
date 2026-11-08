# Dispatch — integrate-gen-doc-drift

```yaml
TASK_ID: integrate-gen-doc-drift
TASK_TYPE: integrate
FEATURE: verify merge-readiness of fix/gen-doc-drift (HEAD acdd602)
WORKTREE: /private/tmp/shipit-fix-gen-drift
BRANCH: fix/gen-doc-drift
BASE_SHA: 6779b84
HEAD_SHA_UNDER_REVIEW: acdd602f4d4603f06cb1bebf3825f5802f962a85
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on acdd602 (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`6779b84` — UI-arms merge + ledger commits): `git fetch`/`merge-base`/dry-run merge of
`acdd602` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (the UI-arms
merge touched `work_item_action_endpoints.dart` + control_plane — this change touches
yaml models/db + generated mirrors; the generated files were regenerated since base, check
for overlap if main's generated surface also advanced); verify provenance; re-run gates on
the merged tree if the base diverged — `dart format`, `dart analyze` (apps/server +
control_plane_client), `dart run tool/run_unit_tests.dart` (apps/server). Report `RESULT:
MERGE_APPROVED` / `BLOCKED`.
