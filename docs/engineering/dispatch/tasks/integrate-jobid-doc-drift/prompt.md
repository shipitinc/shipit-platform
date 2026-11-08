# Dispatch — integrate-jobid-doc-drift

```yaml
TASK_ID: integrate-jobid-doc-drift
TASK_TYPE: integrate
FEATURE: verify merge-readiness of fix/jobid-doc-drift (HEAD 7293b2c)
WORKTREE: /private/tmp/shipit-fix-jobid-drift
BRANCH: fix/jobid-doc-drift
BASE_SHA: ef89c92
HEAD_SHA_UNDER_REVIEW: 7293b2cffdfa1961730534bd18e2959404471b45
REVIEW_PROVENANCE: APPROVE_FOR_MERGE on 7293b2c (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`ef89c92` — store-doc merge `6bad8d9` + ledger commits): `git fetch`/`merge-base`/dry-run
merge of `7293b2c` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (the
store-doc merge touched `operator_action_record.dart`, this touches `operator_action.spy.yaml`
+ its generated mirror — different files, no overlap expected); verify provenance; re-run
gates on the merged tree if the base diverged — `dart format`, `dart analyze` (apps/server),
`dart run tool/run_unit_tests.dart` (apps/server). Report `RESULT: MERGE_APPROVED`/`BLOCKED`.
