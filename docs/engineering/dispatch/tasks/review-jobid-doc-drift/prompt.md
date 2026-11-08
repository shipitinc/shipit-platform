# Dispatch — review-jobid-doc-drift (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-jobid-doc-drift
TASK_TYPE: review
FEATURE: operator_action.spy.yaml jobId doc-drift fix + regenerated mirror (F-265 residual)
WORKTREE: /private/tmp/shipit-fix-jobid-drift
BRANCH: fix/jobid-doc-drift
BASE_SHA: ef89c92
HEAD_SHA_UNDER_REVIEW: 7293b2cffdfa1961730534bd18e2959404471b45
ROUTING_CLASS: PRECISION
```

Independent read-only review of `7293b2c` — `operator_action.spy.yaml` `jobId` doc corrected
(was the false "Set for 'retry'; null for 'stop'") + regenerated `generated/database/
operator_action.dart` mirror.

Verify:
1. The corrected wording is honest — no production path populates jobId (all 7
   OperatorActionRecord constructions omit it; engine copyWith stamps only transitionId),
   mirroring the now-merged `operator_action_record.dart` correction (e60ace6).
2. The generated mirror is mechanical `serverpod generate` output — doc-comment-only diff,
   no hand-edits, no other generated surface drifted (the implementer claims protocol/
   rewrites were byte-identical — verify nothing outside the two owned files changed).
3. No functional change — doc comments only.
4. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server), `dart run tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
