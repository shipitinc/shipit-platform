# Dispatch — fix-store-doc-drift (F-265)

```yaml
TASK_ID: fix-store-doc-drift
TASK_TYPE: implement
FEATURE: residual doc drift — operator_action_record.dart action names 4 tokens (missing reland/reroute) + jobId doc claims "Set for 'retry'" though nothing populates it
AREA: packages/workflow_store doc comments (+ regen if any mirror exists)
WORKTREE: /private/tmp/shipit-fix-store-drift
BRANCH: fix/store-doc-drift
BASE_SHA: HEAD
OWNED_PATHS: [packages/workflow_store/lib/src/**]
READ_ONLY_PATHS: [apps/server/lib/src/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
ROUTING_CLASS: PRECISION
```

F-265 (review-verified residual): `packages/workflow_store/lib/src/operator_action_record.dart`
— the `action` field doc names only retry/stop/deploy/reclaim (missing reland/reroute — wire
constants `operatorRelandActionWire`/`operatorRerouteActionWire` exist server-side), and the
`jobId` doc claims "Set for 'retry'" but no production path populates jobId (verified: all 7
OperatorActionRecord constructions omit it; the engine's copyWith only stamps transitionId).
The sibling spy.yaml doc was fixed in the gen-doc-drift merge — this file is the canonical
source it mirrored.

Task: amend `operator_action_record.dart`'s `action` doc to name the six tokens with the same
OperatorActionKind-vs-wire-constants attribution used in the yaml fixes, and the `jobId` doc
to state honestly that no current producer populates it. Doc-comment-only change — verify no
generated mirror for this file exists needing regen (grep for a protocol mirror). Gates:
`dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
(packages/workflow_store), `dart test` (packages/workflow_store). New commits; no push; no
docker/DB. Report `RESULT: IMPLEMENTED`/`BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.
