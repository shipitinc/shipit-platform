# Dispatch — integrate-store-doc-drift

```yaml
TASK_ID: integrate-store-doc-drift
TASK_TYPE: integrate
FEATURE: verify merge-readiness of fix/store-doc-drift (HEAD e60ace6)
WORKTREE: /private/tmp/shipit-fix-store-drift
BRANCH: fix/store-doc-drift
BASE_SHA: 277331c
HEAD_SHA_UNDER_REVIEW: e60ace665a96e375e88c50ea107ad022c12cca36
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on e60ace6 (gates green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`277331c` — gen-doc merge + ledger commits): `git fetch`/`merge-base`/dry-run merge of
`e60ace6` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (doc-only
change to `packages/workflow_store/lib/src/operator_action_record.dart` — the gen-doc merge
touched yaml + generated, not this file); verify provenance; re-run gates on the merged tree
if the base diverged — `dart format`, `dart analyze` (workflow_store), `dart test`
(workflow_store). Report `RESULT: MERGE_APPROVED` / `BLOCKED`.
