# Dispatch — review-store-doc-drift (PRECISION)

```yaml
TASK_ID: review-store-doc-drift
TASK_TYPE: review
FEATURE: operator_action_record.dart doc-drift correction (F-265)
WORKTREE: /private/tmp/shipit-fix-store-drift
BRANCH: fix/store-doc-drift
BASE_SHA: 277331c
HEAD_SHA_UNDER_REVIEW: e60ace665a96e375e88c50ea107ad022c12cca36
ROUTING_CLASS: PRECISION
```

Independent read-only review of `e60ace6` — doc-comment-only change to
`operator_action_record.dart` (+9/−6): `action` doc names all six tokens (retry/stop/
deploy/reclaim/reland/reroute) with OperatorActionKind-vs-wire-constants attribution;
`jobId` doc honestly states no current producer populates it.

Verify: (1) the vocabulary + attribution match the gen-doc-drift yaml fixes verbatim in
intent (compare `work_item_action_view.yaml`/`operator_action.spy.yaml` action docs);
(2) the jobId claim is accurate — no production path populates jobId (all 7
OperatorActionRecord constructions omit it; engine copyWith stamps only transitionId);
(3) no generated mirror of OperatorActionRecord exists needing regen (verified claim);
(4) pure doc diff — no functional change crept in; (5) gates — `dart format
--set-exit-if-changed .` (root, dart pub get first), `dart analyze` (workflow_store),
`dart test` (workflow_store) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
