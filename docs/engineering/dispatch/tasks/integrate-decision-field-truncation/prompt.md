# Dispatch — integrate-decision-field-truncation

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-decision-field-truncation
TASK_TYPE: integrate
FEATURE: Human-input pages render full field values — no ellipsized fields
WORKTREE: /private/tmp/shipit-fix-truncation + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/decision-field-truncation
BASE_SHA: 582d254
APPROVED_HEAD: 22daf08d2c8ffdd6f1e00b85b356625694d950a9
REVIEW_VERDICT: APPROVE_FOR_MERGE (read-only-edit ruled justified; 1 LOW authoring defect)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. UI-only change (10 files,
all apps/control_plane). Verify: approved HEAD unchanged; rehearsal clean, reviewed blobs
identical; gates on merged tree: `dart format --set-exit-if-changed .` (root, dart pub get
first), `dart analyze` (control_plane), `flutter test` (control_plane); make test-integration
NOT needed (no server/DB-facing change — reasoning). No merge, no push, no docker, no DB.
Report ending exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
