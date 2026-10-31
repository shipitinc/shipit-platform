# Dispatch — integrate-decision-card

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-decision-card
TASK_TYPE: integrate
FEATURE: "Needs your approval" card links to cancelled decision — server fix
WORKTREE: /private/tmp/shipit-fix-decision-card + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/pending-decision-card
BASE_SHA: 226ceb8
APPROVED_HEAD: 57655fbed406c95614fdf0c387a7470870572a7c
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (reviewer f39f86c5; 1 MEDIUM latent follow-up
  filed as F-240, 3 LOW non-blocking)
CURRENT_MAIN: 63b9c13
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
merge rehearsal into current main clean, reviewed blobs identical (4 files: home_endpoints.dart,
control_plane_service.dart, human_decision.dart, home_pending_decisions_test.dart); main advance
since base is docs-only; gates on merged tree: `dart format --set-exit-if-changed .` (root),
`dart analyze` + `dart run tool/run_unit_tests.dart` (apps/server), `dart analyze` + `dart test`
(packages/platform_contracts); state `make test-integration` run or deferred. No docker beyond
make test-integration; no DB writes. Report per subtask-report.md ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
