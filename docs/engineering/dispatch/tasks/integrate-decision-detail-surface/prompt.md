# Dispatch — integrate-decision-detail-surface

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-decision-detail-surface
TASK_TYPE: integrate
FEATURE: Decision-detail page surfaces review verdict + findings + artifact + full context + real option consequences
WORKTREE: /private/tmp/shipit-decision-surface + canonical /Users/alkebut/air/shipit-platform
BRANCH: feat/decision-detail-surface
BASE_SHA: da095e2
APPROVED_HEAD: 07b4b382d00182fe7e14e3acd44b40fd6a6accd3
REVIEW_VERDICT: APPROVE_FOR_MERGE (both scope disclosures ruled on; 3 LOW)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD
unchanged; rehearsal clean, reviewed blobs identical (14 files: control_plane decision_detail +
data + test, control_plane_client protocol + test, server view yaml/generated/mapper +
dartTestSweepRoots + 2 pin tests + manifest); gates on merged tree: `dart format
--set-exit-if-changed .` (root, dart pub get first), `dart analyze` (control_plane,
control_plane_client, apps/server), `flutter test` (control_plane), `dart test`
(control_plane_client), `dart run tool/run_unit_tests.dart` (apps/server); make test-integration
needed (server.dart + view mapper + verification-plan cascade — reasoning). No merge, no push,
no docker beyond make test-integration, no DB. Report ending exactly `RESULT: MERGE_APPROVED`
or `RESULT: INTEGRATION_BLOCKED`.
