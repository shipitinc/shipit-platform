# Dispatch — integrate-infra-decision-resolve

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-infra-decision-resolve
TASK_TYPE: integrate
FEATURE: resolveDecision handles system:provider-health decisions — store-level system-scope resolve
WORKTREE: /private/tmp/shipit-fix-infra-decision + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/infra-decision-resolve
BASE_SHA: 18172c6
APPROVED_HEAD: ccb6538135d21382c5a78974de77b3d69a113409
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (router verified; work-item path byte-identical; residuals filed)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Four files
(workflow_endpoints.dart, system_scope_resolve_decision_test.dart, control_plane_service.dart,
ui_view_mappers.dart — all apps/server/lib/**). Verify: approved HEAD unchanged; rehearsal clean,
reviewed blobs identical; gates on merged tree: `dart format --set-exit-if-changed .` (root, dart
pub get first), `dart analyze` (apps/server), `dart test` (system_scope_resolve_decision_test +
qa_drain_reentry — lib-co-located need explicit paths), `dart run tool/run_unit_tests.dart`
(apps/server); make test-integration needed (resolveDecision drives durable decisions — DB-facing;
reasoning). No merge, no push, no docker beyond make test-integration, no DB. Report ending
exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
