# Dispatch — review-gen-doc-drift (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-gen-doc-drift
TASK_TYPE: review
FEATURE: reconcile stale generated-doc comments — six-token action vocabulary + gateless-deploying exception + "offered through actionContext" corrections
AREA: yaml model/db docs + generated mirrors (serverpod generate)
WORKTREE: /private/tmp/shipit-fix-gen-drift
BRANCH: fix/gen-doc-drift
BASE_SHA: 6779b84
HEAD_SHA_UNDER_REVIEW: acdd602f4d4603f06cb1bebf3825f5802f962a85
ROUTING_CLASS: PRECISION
```

Independent read-only review of `acdd602` — 3 hand-edited yaml sources
(`work_item_action_view.yaml`, `operator_action_summary_view.yaml`,
`operator_action.spy.yaml`) + 6 regenerated mirrors (`generated/database/operator_action.dart`,
`generated/operator_action_summary_view.dart`, `generated/work_item_action_view.dart`,
`client.dart`, `protocol/operator_action_summary_view.dart`,
`protocol/work_item_action_view.dart`).

Verify rigorously:
1. The yaml doc comments now name the real six-token vocabulary (retry/stop/deploy/reclaim/
   reland/reroute) and the gateless-deploying standalone-append exception — matching the
   workflow_store doc amendments verbatim in intent (read both and compare).
2. The generated mirrors are mechanical `serverpod generate` output — verify doc-comment-only
   diffs vs the base, no hand-edits, no functional code drift.
3. `client.dart`'s stale "NOT OFFERED THROUGH actionContext" on relandDeployedWorkItem AND
   rerouteToImplementation is corrected to "OFFERED" — the implementer claims both.
4. The `operator_action.spy.yaml` "only producer is the transaction" claim names the
   gateless-deploying exception honestly (the standalone append in advanceToDeploy exists).
5. The reported discovery (jobId never populated, spy doc left unchanged per the read-only
   workflow_store match) is honest — verify nothing claims a false invariant.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + control_plane_client), `dart run tool/run_unit_tests.dart`
   (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
