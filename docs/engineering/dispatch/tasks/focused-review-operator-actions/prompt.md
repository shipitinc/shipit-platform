# Dispatch — focused-review-operator-actions

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-operator-actions
TASK_TYPE: review
FEATURE: focused re-review of the operator-actions correction (c8d30bb on top of reviewed 5b56608)
WORKTREE: /private/tmp/shipit-feat-operator-actions
BRANCH: feat/operator-actions
BASE_SHA: 6a4d307
REVIEWED_HEAD: 5b56608da51e72b297d355ba8dceba612c89eba9
CORRECTED_HEAD: c8d30bb178bb8b39bcd905a55459c13a923c29da
ROUTING_CLASS: PRECISION
```

Focused re-review — ONLY the corrected findings + regression risk introduced by the corrections;
do NOT repeat the full review unless evidence requires it.

The correction addressed: (MEDIUM 1) zero Flutter coverage — new operator_action_panel_test +
operator_action_copy_test deploy/reclaim group + run_detail_bloc routing group; (MEDIUM 2) the
contract-doc invariant — WorkflowStore.appendOperatorAction + OperatorActionRecord docs amended
to name the gateless-deploying standalone append + audit-first rule; (LOWs) closed-set comments
extended for deploy/reclaim; producedCommitFor stamped-producer test added.

Verify:
1. The reviewed HEAD 5b56608 is preserved (the correction is new commits on top, no rewrite) —
   provenance intact.
2. The Flutter tests are non-vacuous — the panel/copy/bloc tests genuinely cover the findings
   (deploy vs reclaim copy, reason gate, requestId reuse, Escape, the routing per action,
   delegation for other outcomes).
3. The doc amendments honestly name the standalone-append exception + forbid a second one —
   the invariant text is accurate now.
4. Regression risk — the corrections touched apps/control_plane (tests + run_detail_event +
   control_plane_repository), apps/server/test (the endpoints test), packages/workflow_store
   (docs only) — verify nothing outside those, no behavior change crept in, no test weakened.
5. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/control_plane + touched), `flutter test` (apps/control_plane, +553),
   `dart test` (work_item_action_endpoints_test + workflow_store) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_CORRECTIONS` /
`DO_NOT_APPROVE_CORRECTIONS` + `CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:` — and flag the
disclosed residual (work_item_action_view.yaml + generated mirrors + operator_action.spy.yaml doc
drift) for the orchestrator.
