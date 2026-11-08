# Dispatch — fix-jobid-doc-drift (F-265 residual)

```yaml
TASK_ID: fix-jobid-doc-drift
TASK_TYPE: implement
FEATURE: residual — operator_action.spy.yaml jobId doc still says "Set for 'retry'" (false) + generated mirror
AREA: apps/server spy.yaml doc + generated mirror (serverpod generate)
WORKTREE: /private/tmp/shipit-fix-jobid-drift
BRANCH: fix/jobid-doc-drift
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/database/operator_action.spy.yaml, apps/server/lib/src/generated/database/operator_action.dart]
READ_ONLY_PATHS: [packages/workflow_store/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
ROUTING_CLASS: PRECISION
```

The store-doc-drift implementer verified: `operator_action.spy.yaml:57` still documents
`jobId` as "Set for 'retry'; null for 'stop', which arms nothing." — false; NO production
path populates jobId (all 7 OperatorActionRecord constructions omit it; engine copyWith
stamps only transitionId; only deserialization + a test fixture set it). The generated
mirror `generated/database/operator_action.dart` repeats the stale line. Amend the spy.yaml
`jobId` doc to state honestly that no current producer populates it (mirroring the corrected
operator_action_record.dart wording at the now-merged `e60ace6`), then `serverpod generate`
to regen the mirror (or hand-verify the mirror matches if regen is heavier — doc-only).
Gates: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
(apps/server), `dart run tool/run_unit_tests.dart` (apps/server). New commits; no push; no
docker/DB. Report `RESULT: IMPLEMENTED`/`BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.
